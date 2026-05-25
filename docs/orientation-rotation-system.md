# Orientation and Rotation System

This document explains how SmartSense handles orientation, rotation, heading, and coordinate conversion across backend localization, 2D map rendering, AR tracking, AR path overlays, route guidance, and native iOS/Android AR bridges.

It is intended as the complete engineering reference for maintaining or debugging orientation-related behavior. For the short convention checklist, see `AR_CONVENTIONS.md`.

## Executive Summary

The app uses the backend floor-plan orientation as the source of truth for the user's initial direction. That value is usually carried as `ang` on the route's starting `LocationEntity`.

Native AR then tracks relative movement and relative yaw after AR starts. Flutter combines both values:

```text
floor-plan heading from backend + AR heading at session origin = bridge rotation
```

This bridge rotation maps AR world movement into floor-plan pixels and maps route pixels back into AR world coordinates for the visual overlay.

The system has three main frames:

| Frame | Unit | Origin | Positive X | Positive Y/Z | Angle convention |
| --- | --- | --- | --- | --- | --- |
| Floor-plan image | pixels | top-left image corner | right/east | down/south | `0 deg = East`, clockwise |
| Floor-plan math plane | pixels | same logical point | east | north | image Y is flipped |
| AR world | meters | AR session origin | session right/east-like | native up and forward axes | platform pose yaw |

The practical rule is:

```text
0 deg = East
90 deg = South
180 deg = West
270 deg = North
```

Angles must be normalized to `[0, 360)` whenever they are stored, compared, or displayed.

## Backend Orientation

The backend returns floor-plan coordinates and orientation values through navigation and localization endpoints.

### Route Response

Routes are requested from `/generate-instructions` in `NavigationRemoteDataSourceImpl`. The response is parsed into `RouteModel`, `MultiFloorNavigationStepModel`, `NavigationStepModel`, and `LocationModel`.

Important fields:

| Backend field | App model | Meaning |
| --- | --- | --- |
| `x` | `LocationEntity.x` | floor-plan pixel X |
| `y` | `LocationEntity.y` | floor-plan pixel Y |
| `ang` | `LocationEntity.ang` | floor-plan heading/orientation |
| `meters_per_pixel` | `RouteEntity.metersPerPixel` | map scale |

`NavigationRemoteDataSourceImpl` also logs backend orientation. It first checks the top-level `response['ang']`; if that is absent, it checks the first route step's `from.ang`.

### Backend `ang`

`ang` is treated as the user's heading in the floor-plan convention:

```text
0 deg   = East/right
90 deg  = South/down
180 deg = West/left
270 deg = North/up
```

This value is the anchor for AR navigation. When AR starts, `NavigationPage._startArTracking` builds a `LocalizedPose` from the route origin and sets:

```dart
heading: state.currentLocation.ang ??
         widget.userPickedCoordinates?['heading']?.toDouble() ??
         0.0
```

That pose becomes the `referenceFloorplanPose` inside `ArNavigationBloc`.

### Manual Coordinates

When the user manually picks a coordinate, the route request sends `user_picked_coordinates` with:

```json
{
  "x": <picked x>,
  "y": <picked y>,
  "floor": <picked floor>,
  "enabled": true
}
```

If a heading exists on that manual payload, it can be used as a fallback initial heading. Otherwise, the backend route `ang` remains preferred when available.

## Coordinate Conventions

### Floor-Plan Image Coordinates

The floor plan is rendered as an image in Flutter:

```text
origin = top-left
+X     = right
+Y     = down
```

Because the map image follows standard UI coordinates, moving downward increases Y.

### Floor-Plan Math Plane

The AR transform code uses an intermediate math plane:

```text
+X = East
+Y = North
```

Conversion between image and math plane is a Y flip:

```text
mathX = imageX
mathY = -imageY

imageX = mathX
imageY = -mathY
```

This lets AR movement be reasoned about as east/north while still rendering correctly on the top-left-origin image.

### AR Pose Coordinates

Native AR emits pose data through `unav/tracking/ar_pose_stream`. Dart receives it as `ArPose`.

The shared payload fields are:

| Payload key | Dart field | Meaning |
| --- | --- | --- |
| `x` | `ArPose.x` | mapped planar X |
| `y` | `ArPose.y` | mapped planar Y |
| `z` | `ArPose.z` | height |
| `heading` | `ArPose.heading` | native AR yaw in degrees |
| `confidence` | `ArPose.confidence` | tracking quality |
| `worldX` | `ArPose.worldX` | raw native world X |
| `worldY` | `ArPose.worldY` | raw native world Y |
| `worldZ` | `ArPose.worldZ` | raw native world Z |

For planar AR math, the app extracts:

```text
arEast  = worldX
arNorth = -worldZ
```

If raw world values are missing, it falls back to `pose.x` and `-pose.y`.

## Native AR Heading

### iOS ARKit

iOS uses `IOSArTrackingBridge` in `ios/Runner/AppDelegate.swift`.

Current implementation details:

- ARKit runs `ARWorldTrackingConfiguration`.
- `configuration.worldAlignment = .gravity`.
- The AR world is therefore gravity-aligned but not compass-heading-aligned.
- The app bridges this session-relative AR frame to the floor plan in Flutter.

On each AR frame, iOS reads `frame.camera.transform`, extracts translation, and calculates yaw from the camera forward vector:

```swift
cameraForward = -transform.columns.2
planarX = cameraForward.x
planarY = -cameraForward.z
heading = atan2(planarY, planarX)
```

Then it normalizes heading to `[0, 360)`.

The emitted translation mapping is:

```text
x      = translation.x
y      = -translation.z
z      = translation.y
worldX = translation.x
worldY = translation.y
worldZ = translation.z
```

### Android ARCore

Android uses `ArCoreBridge` in `android/app/src/main/kotlin/com/unav/pathlogic/MainActivity.kt`.

On each frame, Android reads `camera.pose`, extracts translation, and calculates heading from the pose Z axis:

```kotlin
cameraForwardX = -zAxis[0]
cameraForwardZ = -zAxis[2]
headingDeg = atan2(-cameraForwardZ, cameraForwardX)
```

Then it normalizes heading to `[0, 360)`.

The emitted translation mapping is:

```text
x      = translation[0]
y      = -translation[2]
z      = translation[1]
worldX = translation[0]
worldY = translation[1]
worldZ = translation[2]
```

### AR Heading Meaning

AR heading is not directly the backend `ang`. It is the camera yaw in the AR session frame. The first usable AR frame is captured as the AR origin. After that, movement and heading changes are interpreted relative to that origin.

This is why the Flutter bridge uses both:

```text
referenceFloorplanPose.heading = backend API heading
originArPose.heading           = AR heading at point zero
currentArPose.heading          = live AR heading
```

## AR Navigation Startup

AR starts in `NavigationPage._startArTracking`.

The page creates a `StartArNavigation` event with:

- `referencePose.x`: route origin X in floor-plan pixels.
- `referencePose.y`: route origin Y in floor-plan pixels.
- `referencePose.heading`: backend `ang` or manual heading fallback.
- `metersPerPixel`: route scale, defaulting to `1.0` if missing.
- `route`: full navigation route.

`ArNavigationBloc._onStartNavigation` stores this as `_referencePose` and normalizes scale:

- If scale is `1.0`, it falls back to `0.05` meters per pixel.
- If app unit is `feet`, it converts feet per pixel to meters per pixel by multiplying by `0.3048`.

Then it starts the native AR repository and waits for AR pose frames.

## Point Zero

The first usable AR frame becomes point zero:

```dart
_originArPose = event.pose;
```

A frame is usable when:

- `confidence >= 1.0`
- heading is finite
- x, y, z are finite

Point zero binds these two facts together:

```text
The backend says the user is at floor-plan position (x, y) with heading ang.
The AR session says the camera is currently at native world pose (x, y, z, yaw).
```

From that point onward, all AR deltas are transformed into floor-plan deltas relative to this bound pair.

At point zero, the transformed floor-plan pose should equal the backend reference:

```text
localized.x       ~= reference.x
localized.y       ~= reference.y
localized.heading == reference.heading
```

Small differences can appear due to floating-point math, but the intended first-frame heading is the backend `ang`.

### Startup Heading Stability

The app must not accept the first high-confidence AR frame blindly. A known field issue is that AR can briefly report a default heading near `0 deg` or `360 deg` before settling to the real startup yaw, often near `90 deg` in the portrait AR setup. If point zero is captured during that brief default state, `sumHeadingDeg` is wrong by about `90 deg`, and the whole map/AR route appears rotated.

This is more likely when the phone is shaking during localization or immediately after AR starts, because AR tracking may report a valid confidence value before yaw is stable.

The mitigation in `ArNavigationBloc` is an origin stabilization gate:

- origin frames must have valid confidence and finite pose values
- several consecutive startup frames must be collected
- headings in the startup window must agree within a small spread
- position in the startup window must not move too much
- a short timeout fallback prevents AR from getting stuck forever if the user keeps moving

The goal is to reject a startup sequence like:

```text
0 deg, 0 deg, 360 deg, 90 deg, 90 deg, 90 deg
```

and initialize only after the stable values dominate the candidate window.

## AR to Floor-Plan Transform

The main conversion is implemented in `ArPoseTransformer.transform`.

Inputs:

```text
currentArPose
originArPose
referenceFloorplanPose
metersPerPixel
```

### Step 1: Extract AR Planar Points

AR world positions are converted into east/north planar points:

```text
origin = (origin.worldX, -origin.worldZ)
current = (current.worldX, -current.worldZ)
```

Then the AR movement delta is:

```text
arDeltaX = current.x - origin.x
arDeltaY = current.y - origin.y
```

Both values are in meters.

### Step 2: Calculate Bridge Rotation

The transform combines backend floor-plan heading with initial AR yaw:

```text
captureHeading = normalize(originArPose.heading)
sumHeadingDeg  = normalize(referenceFloorplanPose.heading + captureHeading)
```

`sumHeadingDeg` is the bridge angle between the AR session frame and the floor-plan math plane.

### Step 3: Rotate AR Delta Into Floor-Plan Math Plane

The AR delta is rotated clockwise by `sumHeadingDeg`:

```text
rotatedX = arDeltaX * cos(sum) + arDeltaY * sin(sum)
rotatedY = arDeltaY * cos(sum) - arDeltaX * sin(sum)
```

Then meters become pixels:

```text
deltaFloorplanMathX = rotatedX / metersPerPixel
deltaFloorplanMathY = rotatedY / metersPerPixel
```

### Step 4: Add Delta to Reference Pose

The backend reference point is converted from image coordinates to math-plane coordinates:

```text
refMathX = reference.x
refMathY = -reference.y
```

Then the transformed current position is:

```text
curMathX = refMathX + deltaFloorplanMathX
curMathY = refMathY + deltaFloorplanMathY
```

Finally the result is converted back to image coordinates:

```text
floorplanX = curMathX
floorplanY = -curMathY
```

### Step 5: Calculate Floor-Plan Heading

Live floor-plan heading is:

```text
floorplanHeading = normalize(sumHeadingDeg - currentArPose.heading)
```

This output becomes `LocalizedPose.heading`.

The result is a complete floor-plan pose:

```text
LocalizedPose(
  x: floorplanX,
  y: floorplanY,
  heading: floorplanHeading
)
```

## Floor-Plan to AR Overlay Transform

The reverse conversion is implemented in `ArNavigationBloc._handleArOverlay`.

It uses the same `sumHeadingDeg` as `ArPoseTransformer` so the AR overlay path and the tracked user pose stay in the same frame.

For each route point `(px, py)`:

1. Convert floor-plan image point to math plane:

```text
mathX = px
mathY = -py
```

2. Convert pixel delta from reference to meters:

```text
deltaMetersX = (mathX - refMathX) * metersPerPixel
deltaMetersY = (mathY - refMathY) * metersPerPixel
```

3. Rotate back into AR world delta using the inverse of the tracking transform:

```text
arDeltaX = deltaMetersX * cos(sum) - deltaMetersY * sin(sum)
arDeltaY = deltaMetersX * sin(sum) + deltaMetersY * cos(sum)
```

4. Add that delta to the AR origin:

```text
targetMathX = originMathX + arDeltaX
targetMathY = originMathY + arDeltaY
```

5. Convert east/north math plane to AR world:

```text
worldX = targetMathX
worldZ = -targetMathY
```

6. Set AR overlay height:

```text
worldY = cameraWorldY - 1.0
```

The overlay is sent to native AR as:

- full path points
- active path points
- next waypoint
- destination point

Native code renders those points as AR scene geometry.

## 2D Map Rotation

`MapView` renders the floor-plan image and route markers. It rotates the map around the screen center so the user's forward direction appears toward the top of the screen.

The map rotation is:

```dart
_mapRotationRad = -(heading + 90.0) * pi / 180.0;
```

Where `heading` is:

```dart
widget.userHeading ?? widget.apiInitialHeading
```

This means:

- Before AR tracking has a live pose, the map uses backend `ang`.
- After AR tracking starts, the map uses the transformed AR floor-plan heading.

Examples:

| Heading | User direction | Map rotation |
| --- | --- | --- |
| `0 deg` | East/right | `-90 deg` |
| `90 deg` | South/down | `-180 deg` |
| `180 deg` | West/left | `-270 deg` |
| `270 deg` | North/up | `-360 deg`, visually same as `0 deg` |

### User Marker Rotation

The user marker is inside the same rotated map layer. To keep the arrow visually pointing up on the screen, the marker is counter-rotated:

```dart
markerHeading = (heading + 90.0) % 360.0;
```

Net effect:

```text
map rotates to align the world under the user
user arrow remains screen-up as "forward"
```

## Guidance Rotation and Turn Direction

Guidance uses the transformed floor-plan pose from AR.

`ArNavigationBloc._buildGuidanceMessage` calculates the target angle to the next waypoint:

```dart
targetAngle = normalize(atan2(waypoint.y - pose.y, waypoint.x - pose.x));
```

Then it computes signed heading delta:

```dart
delta = (targetAngle - currentHeading + 540) % 360 - 180;
```

Interpretation:

```text
delta > 0 => turn right
delta < 0 => turn left
```

If the absolute angle is less than or equal to `25 deg`, the message says to go straight.

Audio guidance uses the same signed delta:

- within `8 deg`: heading is aligned
- positive delta: right cue
- negative delta: left cue

## Off-Route Direction

`PathTrackingService` projects the user onto the route polyline and checks distance from the path.

Off-route thresholds:

| Threshold | Value |
| --- | --- |
| Off-route | `2.0 m` |
| Approaching waypoint | `4.5 m` |
| Turn-now / arrived | `0.95 m` |

Off-route left/right direction is based on a cross product between:

- the user's forward vector
- the correction vector from current position back to the projected path point

Forward vector:

```dart
theta = headingDeg * pi / 180.0;
forward = Offset(cos(theta), -sin(theta));
```

Correction:

```dart
correction = projectedPoint - currentPoint;
```

Cross product:

```dart
cross = forward.dx * correction.dy - forward.dy * correction.dx;
```

Interpretation:

```text
cross < 0 => path is left
cross > 0 => path is right
```

## Heading Values in Debug UI

`MapView` can show a debug panel when debug banners are enabled.

Important fields:

| Label | Source | Meaning |
| --- | --- | --- |
| `API Ang` | `apiInitialHeading` | backend route/localization heading |
| `Pose Ang` | `userHeading` | transformed live floor-plan heading |
| `AR Raw` | currently passed as current pose heading | live transformed heading in current page code |
| `AR Track Len` | `arTravelDistance` | accumulated AR movement in meters |
| `AR Conf` | `confidence` | tracking confidence |
| `Ref Head` | `capturedReferenceHeading` | captured/manual heading if available |
| `Plot Head` | `headingAtStart` | heading captured around route generation |
| `Delta` | `Pose Ang - API Ang` | drift between live transformed heading and initial backend heading |

Note: the current `NavigationPage` passes `arState.currentPose?.heading` into both `userHeading` and `arRawHeading`. That means the debug label `AR Raw` is not the raw native yaw at this call site; it is the transformed floor-plan heading unless the page is changed to expose native raw yaw separately.

## Image and Interface Rotation

Camera images used for localization and relocalization must be oriented correctly before upload.

### iOS

iOS chooses `UIImage.Orientation` from the current interface orientation:

| Interface | Image orientation |
| --- | --- |
| portrait | `.right` |
| landscapeLeft | `.up` |
| landscapeRight | `.down` |
| portraitUpsideDown | `.left` |

### Android

Android rotates captured JPEG bytes so gravity appears down:

| Surface rotation | JPEG rotation |
| --- | --- |
| `ROTATION_0` | `270 deg` |
| `ROTATION_90` | `180 deg` |
| `ROTATION_180` | `90 deg` |
| `ROTATION_270` | `0 deg` |

This image rotation is separate from map heading. It affects backend visual localization, not the map transform directly.

## End-to-End Data Flow

```text
1. User captures image or picks manual location.
2. NavigationBloc sends /generate-instructions request.
3. Backend returns route, origin coordinates, origin ang, meters_per_pixel.
4. NavigationReady stores currentLocation = route.origin.
5. NavigationPage starts AR tracking with referencePose = route.origin + ang.
6. Native AR emits world pose and heading frames.
7. First usable frame becomes originArPose.
8. ArPoseTransformer combines backend ang + origin AR heading.
9. Live AR deltas become floor-plan position and heading.
10. MapView rotates the map using live heading or backend ang fallback.
11. ArNavigationBloc converts route pixels back into AR world points.
12. Native AR renders the route overlay in camera space.
13. PathTrackingService and GuidanceSoundService use transformed heading for instructions.
```

## Invariants and Guardrails

Keep these rules stable unless the whole coordinate system is intentionally redesigned:

1. Backend `ang` is the floor-plan heading source of truth at navigation start.
2. Floor-plan angles use `0 deg = East` and increase clockwise.
3. Image coordinates use `+Y = down`; math-plane coordinates use `+Y = north`.
4. Always normalize heading values to `[0, 360)`.
5. Use the same `sumHeadingDeg` for AR-to-floor-plan tracking and floor-plan-to-AR overlay conversion.
6. Do not mix compass north-based headings with floor-plan headings without an explicit conversion.
7. Do not assume map north is screen-up during navigation; the map rotates to keep user-forward at screen top.
8. Treat `metersPerPixel` as meters in AR logic. Convert feet to meters before using native AR distances.
9. Do not change the native AR world alignment without updating `ArPoseTransformer` and overlay inverse transform together.

## Common Failure Modes

### Map points the wrong way at start

Likely causes:

- backend `ang` is missing or using a different convention
- manual coordinate heading fallback is `0`
- map marker formula was changed independently from map rotation

Check:

- `LocationEntity.ang`
- `NavigationPage._startArTracking`
- `MapView._mapRotationRad`
- marker heading calculation in `MapView`

### AR path appears rotated away from the real corridor

Likely causes:

- `sumHeadingDeg` differs between tracking transform and overlay transform
- native AR heading convention changed
- ARKit/ARCore world alignment changed
- backend `ang` convention changed
- point zero captured an unstable startup heading, often `0 deg` instead of the stable `90 deg`

Check:

- `ArPoseTransformer.transform`
- `ArNavigationBloc._handleArOverlay`
- `ArNavigationBloc._selectStableOriginPose`
- native yaw calculation in `AppDelegate.swift` or `MainActivity.kt`

### Mis-orientation is worse when the phone is shaking

Likely cause:

- AR startup yaw was accepted before it settled

Observed tester pattern:

- easier to reproduce on east-facing and north-facing starts
- difficult to reproduce on west-facing starts
- minor or brief issue on south-facing starts
- sometimes a correction is visible briefly, but most sessions stay wrong because point zero was already anchored to the bad heading

Check:

- startup logs for ignored origin frames
- `Origin AR Heading (Yaw)`
- `Initial Calculated sumHeadingDeg`
- warnings for sensor flicks shortly after point zero

### Position moves in the opposite Y direction

Likely cause:

- image/math-plane Y flip was missed or applied twice

Check:

- `refMathY = -reference.y`
- `fpY = -curMathY`
- `mathY = -py` in overlay conversion

### Turn left/right guidance is inverted

Likely causes:

- heading convention changed from clockwise to counter-clockwise
- `atan2` input order changed
- signed delta formula changed

Check:

- `_buildGuidanceMessage`
- `_signedHeadingDeltaDeg`
- `_signedHeadingDeltaToNextWaypoint`
- `_computeOffRouteDirection`

## Source Map

Primary files:

- `AR_CONVENTIONS.md`: short coordinate-system checklist.
- `lib/features/navigation/data/datasources/navigation_remote_datasource.dart`: route request and backend orientation logging.
- `lib/features/navigation/data/models/location_model.dart`: parses `ang`.
- `lib/features/navigation/presentation/bloc/navigation_bloc.dart`: route initialization, heading capture, state creation.
- `lib/features/navigation/presentation/pages/navigation_page.dart`: starts AR and passes headings to the map.
- `lib/features/ar_navigation/presentation/bloc/ar_navigation_bloc.dart`: AR lifecycle, point zero, overlay conversion, guidance.
- `lib/features/ar_navigation/domain/services/ar_pose_transformer.dart`: AR-to-floor-plan transform.
- `lib/features/ar_navigation/domain/services/path_tracking_service.dart`: path projection, off-route state, left/right correction.
- `lib/shared/widgets/map_view.dart`: 2D map rotation and user marker rotation.
- `ios/Runner/AppDelegate.swift`: iOS ARKit pose, yaw, image orientation, overlay rendering.
- `android/app/src/main/kotlin/com/unav/pathlogic/MainActivity.kt`: Android ARCore pose, yaw, image rotation, overlay rendering.
