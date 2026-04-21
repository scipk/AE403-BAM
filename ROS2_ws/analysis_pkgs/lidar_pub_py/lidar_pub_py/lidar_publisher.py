import argparse
import numpy as np
import rclpy
from rclpy.node import Node

import airsim

from sensor_msgs.msg import PointCloud2, PointField


class LidarPublisher(Node):
    def __init__(
        self,
        host="127.0.0.1",
        port=41451,
        lidar_name="LidarRockUltra",
        vehicle_name="Drone",
        topic_name="/airsim/lidar/LidarRockUltra",
        rate_hz=5.0,  # 🔽 slower for stability
        frame_id="lidar_frame",
    ):
        super().__init__("lidar_publisher")

        self.host = host
        self.port = port
        self.lidar_name = lidar_name
        self.vehicle_name = vehicle_name
        self.topic_name = topic_name
        self.rate_hz = rate_hz
        self.frame_id = frame_id

        self.publisher_ = self.create_publisher(PointCloud2, self.topic_name, 1)

        self.get_logger().info(
            f"Connecting to AirSim at {self.host}:{self.port}..."
        )
        self.client = airsim.MultirotorClient(ip=self.host, port=self.port)
        self.client.confirmConnection()

        self.get_logger().info(
            f'Connected! Publishing "{self.lidar_name}" on "{self.topic_name}" at {self.rate_hz} Hz'
        )

        timer_period = 1.0 / self.rate_hz
        self.timer = self.create_timer(timer_period, self.timer_callback)

    def timer_callback(self):
        try:
            lidar_data = self.client.getLidarData(
                lidar_name=self.lidar_name,
                vehicle_name=self.vehicle_name,
            )

            raw_points = lidar_data.point_cloud

            if raw_points is None or len(raw_points) == 0:
                self.get_logger().warn("No LiDAR points received.")
                return

            # Convert to Nx3
            points = np.asarray(raw_points, dtype=np.float32).reshape(-1, 3)

            # Remove invalid points
            valid = np.all(np.isfinite(points), axis=1)
            points = points[valid, :]

            if points.shape[0] == 0:
                self.get_logger().warn("No valid LiDAR points after filtering.")
                return

            # 🔥 Downsample to 4000 points
            max_points = 4000
            if points.shape[0] > max_points:
                idx = np.random.choice(points.shape[0], max_points, replace=False)
                points = points[idx, :]

            msg = self.points_to_pointcloud2(points)
            self.publisher_.publish(msg)

            self.get_logger().debug(f"Published {points.shape[0]} points")

        except Exception as e:
            self.get_logger().error(f"LiDAR publish failed: {e}")

    def points_to_pointcloud2(self, points):
        msg = PointCloud2()

        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = self.frame_id

        msg.height = 1
        msg.width = points.shape[0]

        msg.fields = [
            PointField(name="x", offset=0, datatype=PointField.FLOAT32, count=1),
            PointField(name="y", offset=4, datatype=PointField.FLOAT32, count=1),
            PointField(name="z", offset=8, datatype=PointField.FLOAT32, count=1),
        ]

        msg.is_bigendian = False
        msg.point_step = 12
        msg.row_step = msg.point_step * points.shape[0]
        msg.is_dense = True

        msg.data = points.astype(np.float32).tobytes()

        return msg


def main(args=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=41451)
    parser.add_argument("--lidar-name", default="LidarRockUltra")
    parser.add_argument("--vehicle-name", default="Drone")
    parser.add_argument("--topic-name", default="/airsim/lidar/LidarRockUltra")
    parser.add_argument("--rate", type=float, default=5.0)
    parser.add_argument("--frame-id", default="lidar_frame")

    parsed_args, _ = parser.parse_known_args()

    rclpy.init(args=args)

    node = LidarPublisher(
        host=parsed_args.host,
        port=parsed_args.port,
        lidar_name=parsed_args.lidar_name,
        vehicle_name=parsed_args.vehicle_name,
        topic_name=parsed_args.topic_name,
        rate_hz=parsed_args.rate,
        frame_id=parsed_args.frame_id,
    )

    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.get_logger().info("Shutting down lidar_publisher...")
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
