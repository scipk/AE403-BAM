# BAM Simulation Bus Variable Reference
## Trajectory (Traj_Iner) and Equations of Motion (EOM_Sensed) Documentation

**Generated:** 2026-03-28  
**Repository:** wyattowelch/AE403-BAM  
**Project:** SDSU AE403W Senior Design Project

---

## Table of Contents
1. [Traj_Iner (BUS_REF_INPUT_INER)](#traj_iner)
2. [EOM_Sensed (BUS_EOM)](#eom_sensed)
   - [InertialData](#inertialdata)
   - [WorldRelativeData](#worldrelativedata)
   - [AirRelativeData](#airrelativedata)

---

## <a name="traj_iner"></a>1. Traj_Iner Structure (BUS_REF_INPUT_INER)

**Type:** Bus  
**Size:** 1  
**Frame of Reference:** Inertial Frame  
**Description:** Reference trajectory and desired heading inputs in inertial coordinates for trajectory tracking and guidance.

### Variables

| Variable | Size | Data Type | Frame | Description |
|----------|------|-----------|-------|-------------|
| **pos_i** | 3 | double | Inertial | Position vector in inertial frame coordinates (North, East, Down or X, Y, Z components). |
| **vel_i** | 3 | double | Inertial | Velocity vector in inertial frame coordinates. |
| **acc_i** | 3 | double | Inertial | Acceleration vector in inertial frame coordinates. |
| **chi_des** | 1 | double | Inertial | Desired heading angle relative to reference direction. |
| **chi_dot_des** | 1 | double | Inertial | Desired heading rate (time derivative of heading angle). |
| **time_violate_flag** | 1 | double | — | Flag indicating whether time constraint has been violated (boolean flag). |

**Total Variables:** 6  
**Total Data Size:** 3 + 3 + 3 + 1 + 1 + 1 = 12 doubles (96 bytes)

---

## <a name="eom_sensed"></a>2. EOM_Sensed Structure (BUS_EOM)

**Type:** Bus  
**Size:** 1  
**Description:** Sensed equations of motion containing inertial, world-relative, and air-relative dynamics data.

`EOM_Sensed` contains 3 top-level sub-buses:

---

### <a name="inertialdata"></a>2.1 InertialData (BUS_INERTIAL)

**Type:** Bus  
**Size:** 1  
**Frame of Reference:** Body frame relative to Inertial frame  
**Description:** Inertial reference frame dynamics - position, velocity, acceleration, and orientation data.

#### Variables

| Variable | Size | Data Type | Frame | Description |
|----------|------|-----------|-------|-------------|
| **Pos_bii** | 3 | double | Inertial | Position of body frame origin expressed in inertial frame coordinates. |
| **Vel_bIi** | 3 | double | Inertial | Velocity of body frame expressed in inertial frame coordinates. |
| **Accel_bIi** | 3 | double | Inertial | Acceleration of body frame in inertial frame coordinates. |
| **Asensed_bIb** | 3 | double | Body | Sensed acceleration measured by accelerometer in body-fixed axes. |
| **Q_i2b** | 4 | double | — | Quaternion (q0, q1, q2, q3) defining rotation from inertial to body frame. |
| **Omeg_BIb** | 3 | double | Body | Angular velocity of body relative to inertial frame, expressed in body-fixed axes. |
| **OmegDtI_BIb** | 3 | double | Body | Angular acceleration (time derivative of angular velocity), expressed in body frame. |

**Subtotal Variables:** 7  
**Subtotal Data Size:** 3 + 3 + 3 + 3 + 4 + 3 + 3 = 22 doubles (176 bytes)

---

### <a name="worldrelativedata"></a>2.2 WorldRelativeData (BUS_WORLD_REL)

**Type:** Bus  
**Size:** 1  
**Frame of Reference:** Body frame relative to Earth/World frame  
**Description:** Earth-relative dynamics including position, altitude, orientation, and kinematic rates.

#### Variables

| Variable | Size | Data Type | Frame | Description |
|----------|------|-----------|-------|-------------|
| **Pos_bee** | 3 | double | Earth | Position of body relative to Earth frame center in Earth-fixed coordinates. |
| **Pos_beh_topo** | 3 | double | Topographic | Position of body relative to reference point in local topographic coordinates (North, East, Down). |
| **LatLonAlt** | 1 | Bus: BUS_LAT_LONG_ALT | Geographic | Nested bus containing latitude, longitude, and geodetic altitude. |
| **AltMSL** | 1 | double | Earth | Altitude above Mean Sea Level in meters or feet. |
| **AltAGL** | 1 | double | Earth | Altitude Above Ground Level (height above terrain) in meters or feet. |
| **AltPresMSL** | 1 | double | Earth | Pressure altitude referenced to standard Mean Sea Level conditions. |
| **Euler** | 1 | Bus: BUS_EULER | — | Nested bus containing Euler angles (roll, pitch, yaw). |
| **Q_h2b** | 4 | double | — | Quaternion defining rotation from heading frame to body frame. |
| **Q_i2h** | 4 | double | — | Quaternion defining rotation from inertial frame to heading frame. |
| **gamma** | 1 | double | World | Flight path angle relative to Earth horizon. |
| **chi** | 1 | double | World | Heading angle relative to Earth (true heading). |
| **Omeg_BEb** | 3 | double | Body | Angular velocity of body relative to Earth, expressed in body frame. |
| **Omeg_BHb** | 3 | double | Body | Angular velocity of body relative to heading frame, expressed in body frame. |
| **Vel_bEb** | 3 | double | Body | Velocity of body relative to Earth, expressed in body frame. |
| **Vel_bEh** | 3 | double | Heading | Velocity of body relative to Earth, expressed in heading frame. |
| **Omeg_HEh** | 3 | double | Heading | Angular velocity of heading frame relative to Earth, expressed in heading frame. |
| **VelDtE_bEb** | 3 | double | Body | Acceleration of velocity relative to Earth, expressed in body frame. |
| **VelDtH_bEh** | 3 | double | Heading | Acceleration of velocity relative to heading frame, expressed in heading frame. |
| **gammadot** | 1 | double | World | Time derivative of flight path angle (angular velocity about lateral axis). |
| **chidot** | 1 | double | World | Time derivative of heading angle (yaw rate about vertical axis). |

#### Nested Bus: LatLonAlt (BUS_LAT_LONG_ALT)

**Frame of Reference:** Geographic (WGS84 or equivalent datum)

| Variable | Size | Data Type | Description |
|----------|------|-----------|-------------|
| **LatGeod** | 1 | double | Geodetic latitude in degrees or radians (±90°). |
| **Lon** | 1 | double | Longitude in degrees or radians (±180°). |
| **AltGeod** | 1 | double | Geodetic altitude above WGS84 reference ellipsoid in meters or feet. |

#### Nested Bus: Euler (BUS_EULER)

**Frame of Reference:** Body frame relative to World/Earth frame

| Variable | Size | Data Type | Description |
|----------|------|-----------|-------------|
| **phi** | 1 | double | Roll angle (rotation about body longitudinal/x-axis) in radians. |
| **theta** | 1 | double | Pitch angle (rotation about body lateral/y-axis) in radians. |
| **psi** | 1 | double | Yaw angle (rotation about body vertical/z-axis) in radians. |

**Subtotal Variables:** 23 (including nested buses)  
**Subtotal Data Size:** 3 + 3 + 3 + 1 + 1 + 1 + 3 + 4 + 4 + 1 + 1 + 3 + 3 + 3 + 3 + 3 + 3 + 3 + 1 + 1 = 47 doubles (376 bytes)

---

### <a name="airrelativedata"></a>2.3 AirRelativeData (BUS_AIR_REL)

**Type:** Bus  
**Size:** 1  
**Frame of Reference:** Body frame relative to Wind/Air frame  
**Description:** Aerodynamic state variables including airspeed components, angles, and aerodynamic rates.

#### Variables

| Variable | Size | Data Type | Frame | Description |
|----------|------|-----------|-------|-------------|
| **Vel_bWb** | 3 | double | Body | Velocity of body relative to wind, expressed in body frame (true airspeed vector). |
| **VelDtB_bWb** | 3 | double | Body | Time derivative of airspeed in body frame. |
| **Omeg_BWb** | 3 | double | Body | Angular velocity of body relative to wind frame, expressed in body frame. |
| **Vtot** | 1 | double | — | Total airspeed magnitude (true airspeed). |
| **Veas** | 1 | double | — | Equivalent airspeed (normalized to sea-level conditions). |
| **Vcas** | 1 | double | — | Calibrated airspeed (instrument reading corrected for instrument error). |
| **Mach** | 1 | double | — | Mach number (airspeed relative to local speed of sound). |
| **qbar** | 1 | double | — | Dynamic pressure (0.5 × rho × V²). |
| **qc** | 1 | double | — | Impact pressure (total pressure minus static pressure). |
| **alpha** | 1 | double | Body | Angle of attack (pitch angle relative to relative wind). |
| **beta** | 1 | double | Body | Sideslip angle (yaw angle relative to relative wind). |
| **mu** | 1 | double | Body | Bank angle (roll angle) relative to wind frame. |
| **gamma** | 1 | double | Air | Flight path angle relative to airflow. |
| **chi** | 1 | double | Air | Heading angle relative to wind direction. |
| **Vtotdot** | 1 | double | — | Time derivative of total airspeed (acceleration along wind direction). |
| **alphadot** | 1 | double | — | Time derivative of angle of attack (angular acceleration pitch-wise). |
| **betadot** | 1 | double | — | Time derivative of sideslip angle (angular acceleration yaw-wise). |
| **mudot** | 1 | double | — | Time derivative of bank angle (angular acceleration roll-wise). |
| **gammadot** | 1 | double | — | Time derivative of flight path angle. |
| **chidot** | 1 | double | — | Time derivative of heading angle relative to wind. |
| **alphaTotal** | 1 | double | Body | Total angle of attack including control surface deflections and side-slip effects. |
| **phiAero** | 1 | double | Body | Aerodynamic roll angle relative to wind frame. |
| **Q_h2v** | 4 | double | — | Quaternion defining rotation from heading frame to velocity/wind frame. |
| **Omeg_VHb** | 3 | double | Body | Angular velocity of velocity frame relative to heading frame, expressed in body frame. |

**Subtotal Variables:** 24  
**Subtotal Data Size:** 3 + 3 + 3 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 4 + 3 = 54 doubles (432 bytes)

---

## Summary Statistics

| Bus | Sub-Components | Total Variables | Data Size (bytes) |
|-----|-----------------|-----------------|-------------------|
| **Traj_Iner** | None | 6 | 96 |
| **EOM_Sensed** | | | |
| -> InertialData | None | 7 | 176 |
| -> WorldRelativeData | LatLonAlt, Euler | 23 | 376 |
| -> AirRelativeData | None | 24 | 432 |
| **EOM_Sensed Total** | 3 | 54 | 984 |
| **COMBINED TOTAL** | — | **60** | **1,080 bytes** |

---

## Frame of Reference Legend

- **Inertial Frame (i):** Non-rotating reference frame fixed to Earth's center
- **Body Frame (b):** Reference frame fixed to aircraft body; origin at center of gravity
- **Earth/World Frame (E, e):** Rotating with Earth; typically NED (North-East-Down) orientation
- **Heading Frame (h):** Intermediate frame aligned with true heading
- **Topographic Frame:** Local tangent plane coordinate system
- **Wind/Velocity Frame (W, v):** Aligned with relative wind direction
- **Geographic:** Latitude, longitude, altitude datum (WGS84)

---

## Naming Conventions

### Subscript Notation
- First letter: Point of interest (B = Body, H = Heading, I = Inertial, E = Earth, W = Wind, V = Velocity)
- Middle letters: Reference frame or relationship
- Last letters: Expression frame

### Examples
- `Vel_bEb`: Velocity of body **b** relative to Earth **E**, expressed in body frame **b**
- `Q_i2b`: Quaternion rotation from inertial **i** to body **b**
- `Omeg_BIb`: Angular velocity of body **B** relative to inertial **I**, expressed in body **b**

### Variable Prefixes
- `Pos_`: Position vector
- `Vel_`: Velocity vector
- `Acc/Accel_`: Acceleration vector
- `Omeg_`: Angular velocity vector
- `OmegDt`: Angular acceleration vector
- `Q_`: Quaternion (4 components)
- `dot`: Time derivative

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-28