# AR Navigation Coordinate System & Conventions

## Core Coordinate System (Clockwise Math Plane)
This project uses a non-standard coordinate system for mapping floorplans to the real world. Ensure all new logic adheres to these rules to maintain synchronization between the 2D Map and AR view.

### Angular Mapping
- **Reference:** 0° starts at **East (3 o'clock)**.
- **Direction:** Angles increase **Clockwise**.
- **Key Bearings:**
    - `0°`   = East  (3 o'clock)
    - `90°`  = South (6 o'clock)
    - `180°` = West  (9 o'clock)
    - `270°` = North (12 o'clock)

### Coordinate Mapping (Pixels to Meters)
- **Image Origin:** Top-Left (Standard UI coordinates).
- **Y-Axis:** Positive Y is **South**.
- **X-Axis:** Positive X is **East**.
- **Scale:** Real-world movement is calculated using `metersPerPixel` (default fallback `0.05`).

## Component Specific Logic

### 1. 2D Map (MapView)
- **User Marker Rotation:** To align the backend's Math Angle with Flutter's UI rotation (where 0° is North/12 o'clock):
  `UI_Rotation = (Math_Angle + 90.0)`
- **Map Orientation:** Currently static (North-up). Do not rotate the map view automatically without user request.

### 2. AR Guidance (ArNavigationBloc)
- **Target Angle:** Calculated using `atan2(waypoint.y - user.y, waypoint.x - user.x)`.
- **Instruction Logic:**
    - Calculate `headingDelta` between `user.heading` and `targetAngle`.
    - If `delta > 0`: Turn Right.
    - If `delta < 0`: Turn Left.

### 3. AR Path Plotting
- **Forward Axis:** AR Kit/Core uses **-Z** for forward.
- **Alignment:** Floorplan points are rotated by `-(90 + initial_heading)` to ensure the path extends straight from the camera's perspective when the user faces the destination.

## Implementation Guardrails
- **NEVER** assume 0° is North.
- **NEVER** use counter-clockwise math (e.g. standard `atan2` without checking orientation).
- **ALWAYS** verify that `ang` from the backend is treated as the source of truth for initial orientation.
