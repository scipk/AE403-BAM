import rclpy
from rclpy.node import Node
from sensor_msgs.msg import PointCloud2, PointField
import numpy as np
import msgpack
import socket
import struct
import threading
import time


class AirsimRpcClient:
    """Minimal AirSim msgpack-rpc client — no tornado dependency."""

    def __init__(self, ip="127.0.0.1", port=41451):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((ip, port))
        self.packer = msgpack.Packer(use_bin_type=True)
        self.unpacker = msgpack.Unpacker(raw=False)
        self.msg_id = 0
        self.lock = threading.Lock()

    def _call(self, method, *args):
        with self.lock:
            self.msg_id += 1
            # msgpack-rpc request: [type(0), msgid, method, params]
            request = self.packer.pack([0, self.msg_id, method, list(args)])
            self.sock.sendall(request)

            # Read response
            while True:
                data = self.sock.recv(4096)
                if not data:
                    raise ConnectionError("AirSim connection lost")
                self.unpacker.feed(data)
                for response in self.unpacker:
                    # response: [type(1), msgid, error, result]
                    if response[2] is not None:
                        raise RuntimeError(f"AirSim RPC error: {response[2]}")
                    return response[3]

    def ping(self):
        return self._call("ping")

    def get_lidar_data(self, lidar_name, vehicle_name):
        result = self._call("getLidarData", lidar_name, vehicle_name)
        # result is a dict with 'point_cloud' as a flat list of floats
        return result

    def close(self):
        self.sock.close()


class LidarPublisher(Node):
    def __init__(self):
        super().__init__('lidar_publisher')

        self.declare_parameter('vehicle_name', 'Drone')
        self.declare_parameter('lidar_name', 'LidarRockUltra')
        self.declare_parameter('publish_rate', 10.0)
        self.declare_parameter('topic_name', '/airsim/lidar/LidarRockUltra')

        vehicle = self.get_parameter('vehicle_name').value
        lidar = self.get_parameter('lidar_name').value
        rate = self.get_parameter('publish_rate').value
        topic = self.get_parameter('topic_name').value

        self.vehicle_name = vehicle
        self.lidar_name = lidar

        # Connect to AirSim
        self.get_logger().info('Connecting to AirSim at 127.0.0.1:41451...')
        self.client = AirsimRpcClient("127.0.0.1", 41451)
        result = self.client.ping()
        self.get_logger().info(
            f'Connected! Publishing "{lidar}" on "{topic}" at {rate} Hz'
        )

        self.publisher_ = self.create_publisher(PointCloud2, topic, 10)
        self.timer = self.create_timer(1.0 / rate, self.timer_callback)
        self.msg_count = 0

    def timer_callback(self):
        try:
            result = self.client.get_lidar_data(self.lidar_name, self.vehicle_name)
        except Exception as e:
            self.get_logger().warn(f'LiDAR read failed: {e}')
            return

        # Extract point cloud — AirSim returns a dict; the key may be
        # 'point_cloud' or embedded differently depending on version.
        # Try common keys:
        raw_points = None
        if isinstance(result, dict):
            raw_points = result.get('point_cloud') or result.get('points')
        elif isinstance(result, (list, tuple)):
            raw_points = result

        if not raw_points or len(raw_points) < 3:
            return

        points = np.array(raw_points, dtype=np.float32).reshape(-1, 3)

        msg = PointCloud2()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = 'lidar_frame'
        msg.height = 1
        msg.width = points.shape[0]
        msg.fields = [
            PointField(name='x', offset=0,  datatype=PointField.FLOAT32, count=1),
            PointField(name='y', offset=4,  datatype=PointField.FLOAT32, count=1),
            PointField(name='z', offset=8,  datatype=PointField.FLOAT32, count=1),
        ]
        msg.is_bigendian = False
        msg.point_step = 12
        msg.row_step = 12 * points.shape[0]
        msg.data = points.tobytes()
        msg.is_dense = True

        self.publisher_.publish(msg)

        self.msg_count += 1
        if self.msg_count % 100 == 0:
            self.get_logger().info(
                f'Published {self.msg_count} scans ({points.shape[0]} pts last)'
            )

    def on_shutdown(self):
        self.client.close()


def main(args=None):
    rclpy.init(args=args)
    node = LidarPublisher()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    node.on_shutdown()
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()