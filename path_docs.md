# AR Indoor Navigation Path Stabilization

Keeping AR hallway guidance lines centered when AI orientation is off by 2–5 degrees.

## Document purpose

This document explains how to prevent an AR navigation path from drifting into walls by combining AI pose estimation, AR floor/wall detection, hallway centerline correction, and route smoothing.

---

## 1. Executive Summary

The current issue is caused by small yaw/orientation errors from the AI model. In indoor AR navigation, even a 2–5 degree heading error can make a projected route line drift into walls, especially when the corridor is long.

The solution is **not** to trust the AI orientation directly. Instead, the app should constrain the rendered AR line to the walkable corridor using:

- Floor detection
- Wall or boundary detection
- Centerline snapping
- Temporal smoothing

The recommended design is to use the indoor map or navmesh as the source of truth for walkable areas, while ARKit or ARCore provides local scene understanding to correct small drift. AR should be treated as a **correction layer**, not the main navigation authority.

---

## 2. Problem Statement

The app shows an AR line on the floor to guide users through indoor hallways. The AI model estimates the user origin orientation, but sometimes the origin is off by a few degrees. This creates a visual mismatch between the route and the real corridor.

Symptoms:

- The AR path may enter walls.
- The line may not remain in the center of the hallway.
- The error increases with distance from the origin.
- Small heading errors can become large lateral errors after several meters.
- The user may lose trust in the guidance system.

**Example:**

```
lateral drift ≈ distance × tan(yaw_error)
10 m path with 5° yaw error ≈ 0.87 m sideways drift
```

---

## 3. High-Level Solution

The AR route should go through a correction pipeline before rendering. The goal is to keep the path on the floor, inside the walkable corridor, and centered between hallway boundaries.

```
AI pose + route polyline
        ↓
AR floor detection
        ↓
Wall / boundary / depth detection
        ↓
Hallway centerline estimation
        ↓
Yaw correction + path snapping
        ↓
Smoothed AR route rendering
```

---

## 4. Platform Capabilities

| Platform        | Useful capability                                                       | Use in this project                                                                | Reliability notes                                                                                          |
| --------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| iOS / ARKit     | Plane detection, scene reconstruction, mesh classification              | Detect floor, walls, ceiling-like surfaces, and real-world geometry                | Best results on LiDAR-supported devices. Mesh reconstruction gives stronger geometry awareness.            |
| Android / ARCore| Plane detection, hit testing, Depth API, raw depth                      | Detect floor planes and infer vertical boundaries from depth/point data            | Wall detection may be weaker on low-texture surfaces; depth support varies by device.                      |
| Flutter layer   | UI, route state, voice guidance, app logic                              | Control navigation state and receive corrected route points from native AR         | Flutter AR plugins may not expose every advanced native AR feature.                                        |

ARKit can provide scene reconstruction and mesh information for real-world geometry. ARCore provides environmental understanding, plane detection, hit testing, and the Depth API. ARCore Scene Semantics is more focused on outdoor classes, so it should not be the main indoor wall/floor solution for this project. See the **References** section.

---

## 5. Recommended Architecture

For a production-quality indoor AR navigation system, separate the responsibilities clearly:

| Layer                       | Responsibility                                                                                | Notes                                                |
| --------------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Indoor map / navmesh        | Defines walkable corridors, hallway centerlines, restricted areas, stairs, doors, junctions.  | This should be the source of truth.                  |
| AI localization model       | Estimates user position and orientation.                                                      | May have small yaw/origin errors; needs correction.  |
| ARKit / ARCore native module| Detects floor, planes, depth, mesh, camera pose, and local geometry.                          | Used for local correction and rendering alignment.   |
| Correction engine           | Projects route to floor, corrects yaw, clamps route to corridor, smooths updates.             | This is the key module for your issue.               |
| Flutter app                 | Handles UI, permissions, route selection, voice guidance, state, and user flow.               | Flutter receives corrected AR route data.            |

---

## 6. Core Techniques

### 6.1 Project the AR Line Onto the Floor

Every route point should be projected onto the detected floor plane instead of being rendered directly from AI coordinates. This keeps the line visually attached to the floor.

```
for each routePoint:
    floorHit = raycastDown(routePoint.x, routePoint.z)
    routePoint.y = floorHit.y + 0.02m
```

### 6.2 Detect Hallway Boundaries

The app should estimate the left and right corridor boundaries. On iOS, this can come from ARKit mesh or vertical planes. On Android, this can come from ARCore depth, point cloud, or fitted vertical planes. The boundaries do not need to be perfect; they only need to provide enough confidence to identify the walkable center.

```
leftWall  = nearest vertical surface on user-left side
rightWall = nearest vertical surface on user-right side
center    = midpoint(leftWall, rightWall)
```

### 6.3 Snap the Route Toward the Hallway Center

Instead of hard-snapping the line, use weighted correction so the path does not jump suddenly.

```
correctedPoint = lerp(originalPoint, hallwayCenterPoint, 0.30)
```

### 6.4 Correct Yaw Using Hallway Direction

If the hallway is mostly straight, its direction can be estimated from wall planes or centerline segments. Compare that direction against the AI heading, then apply a small smoothed correction.

```
yawError = hallwayDirection - aiHeading
if abs(yawError) < 8°:
    correctedHeading = smooth(previousHeading, aiHeading + yawError)
```

### 6.5 Clamp the Route to a Walkable Navmesh

If indoor map data exists, every rendered route point should be clamped to the nearest valid walkable area. This is more reliable than using live wall detection alone.

```
if routePoint outside walkablePolygon:
    routePoint = nearestPointOnHallwayCenterline(routePoint)
```

---

## 7. Full Algorithm

1. Start AR session.
2. Detect floor plane.
3. Load indoor map and route polyline.
4. Project all route points onto detected floor.
5. Detect wall-like vertical planes or depth boundaries.
6. Estimate hallway centerline.
7. Compare AI heading with hallway direction.
8. Apply smoothed yaw correction.
9. Shift route points toward hallway centerline.
10. Clamp route points inside walkable navmesh.
11. Render AR line.
12. Repeat correction every frame or at a controlled interval.

---

## 8. Flutter Implementation Recommendation

For a serious indoor AR navigation product, use Flutter for the app layer but implement the advanced AR scene understanding and rendering through native modules.

| Do in Flutter                                          | Do in native AR module                |
| ------------------------------------------------------ | ------------------------------------- |
| Navigation state, route selection, destination search  | ARKit/ARCore session management       |
| Voice guidance and accessibility UI                    | Floor plane detection                 |
| Indoor map loading and path instructions               | Depth/mesh/plane processing           |
| API/backend communication                              | AR line rendering and anchors         |
| Debug panels and user settings                         | Camera pose, hit testing, raycasting  |

**Recommended module boundary:** Flutter should send route/map data to the native AR layer. The native AR layer should return corrected route points, floor confidence, wall confidence, and heading correction values.

---

## 9. MVP and Advanced Roadmap

### 9.1 MVP Version

- Detect floor plane.
- Render AR line slightly above floor.
- Use indoor map hallway centerline.
- Clamp route points to walkable corridor.
- Apply yaw smoothing and line smoothing.
- Show debug values: AI heading, corrected heading, floor confidence, lateral drift.

### 9.2 Advanced Version

- Use ARKit scene reconstruction on LiDAR devices.
- Use ARCore Depth API and raw depth for Android-supported devices.
- Detect left/right wall boundaries dynamically.
- Estimate hallway center from live geometry.
- Auto-calibrate AI orientation using wall direction.
- Use persistent anchors or visual localization for long sessions.
- Add confidence scoring and fallback modes.

---

## 10. Confidence and Fallback Logic

The correction system should not always trust AR geometry. It should calculate confidence and choose the safest mode.

| Condition                                       | Action                                       | Reason                                                |
| ----------------------------------------------- | -------------------------------------------- | ----------------------------------------------------- |
| Floor detected with high confidence             | Project route onto floor                     | Prevents floating or wall-attached route.             |
| Both hallway sides detected                     | Snap route toward center                     | Keeps route visually centered.                        |
| Only one wall detected                          | Use map centerline plus one-wall offset      | Avoids over-correcting from incomplete geometry.      |
| No reliable wall/depth data                     | Use indoor map centerline only               | Safer than guessing from bad AR data.                 |
| AI yaw error appears greater than threshold     | Request recalibration or slow correction     | Prevents sudden route rotation.                       |

---

## 11. Suggested Native AR Output Data Model

```json
{
  "floorDetected": true,
  "floorY": 0.03,
  "floorConfidence": 0.92,
  "leftBoundaryDistance": 1.15,
  "rightBoundaryDistance": 1.20,
  "wallConfidence": 0.78,
  "hallwayDirectionDegrees": 91.5,
  "aiHeadingDegrees": 96.0,
  "yawCorrectionDegrees": -4.5,
  "correctedHeadingDegrees": 91.5,
  "correctedRoutePoints": [
    { "x": 0.0, "y": 0.05, "z": 0.0 },
    { "x": 0.0, "y": 0.05, "z": 1.0 }
  ]
}
```

---

## 12. Testing Plan

- Test 0°, 2°, 5°, and 8° artificial yaw errors.
- Test short hallways, long hallways, turns, doors, open areas, and intersections.
- Measure lateral route drift in centimeters.
- Check whether the line remains inside the walkable polygon.
- Test low-texture walls, glass walls, shiny floors, and low-light environments.
- Record debug videos with AI heading, corrected heading, and wall/floor confidence overlay.

---

## 13. Important Risks

- AR wall detection can fail on plain white walls or poor lighting.
- Depth is not available on all Android devices.
- LiDAR-based mesh reconstruction is available only on supported Apple devices.
- Scene understanding can be noisy during fast movement.
- Hard-snapping the route can cause visual jitter; smoothing is required.
- Indoor maps must be accurate; otherwise clamping can move the line to the wrong place.

---

## 14. Final Recommendation

The best solution is to render the AR path as a **corrected, constrained visualization**. The AI model should estimate the pose, but the final displayed route should be:

1. Projected onto the AR-detected floor.
2. Corrected using hallway geometry.
3. Smoothed over time.
4. Clamped to an indoor map / navmesh centerline.

This will prevent a 2–5 degree origin orientation error from making the AR path enter walls.

---

## 15. References

- Apple Developer Documentation — ARKit scene reconstruction and mesh classification: <https://developer.apple.com/documentation/ARKit/visualizing-and-interacting-with-a-reconstructed-scene>
- Google ARCore Documentation — Overview: <https://developers.google.com/ar/develop>
- Google ARCore Documentation — Depth API: <https://developers.google.com/ar/develop/depth>
- Google ARCore Documentation — Fundamentals (plane detection limits on low-texture surfaces): <https://developers.google.com/ar/develop/fundamentals>
- Google ARCore Documentation — Scene Semantics (outdoor labels): <https://developers.google.com/ar/develop/c/scene-semantics>
- Android Developers — Jetpack XR ARCore depth & semantic identification: <https://developer.android.com/develop/xr/jetpack-xr-sdk/arcore/depth>

---

# Appendix A — Solution Fitted to Current Codebase

> Added after reviewing the existing smart_sense app. The original document is **diagnostically correct** but proposes work that is partially redundant with code that already ships, and partially overkill for an iOS-only product with no LiDAR baseline. This appendix narrows the plan to what actually fixes the reported symptom: **AR path drifts into walls when backend heading or origin ARKit `ang` is even slightly off.**

## A.1 Real Root Cause

The displayed AR path is built from server route points transformed through `originArPose` (the ARKit pose captured at localization time). Pipeline:

```
floorplanRoutePoint  ──▶  floorplanToArWorld(p, originArPose, serverAng)  ──▶  SCNNode in AR scene
```

If **either** of these is wrong by `θ`:

- backend `ang` (server-reported heading at the localization frame), or
- `originArPose.eulerAngles.y` (ARKit yaw at capture instant — depends on compass + tracking quality)

then the entire AR path is rotated by `θ` around the origin point. Lateral error grows linearly with corridor length:

```
lateral_drift = corridor_length × tan(θ)
θ = 3°, length = 12 m  →  drift ≈ 0.63 m  →  inside wall
```

Snap-to-route fixes the **map blue dot** (2D floorplan space) but does **nothing** for the AR scene rendering, because the path SCNNodes are anchored in AR world space using the same wrong `θ`.

## A.2 What Already Exists in This Repo

| Boss doc technique                          | Current code                                                                  | Status                  |
| ------------------------------------------- | ------------------------------------------------------------------------------ | ----------------------- |
| §6.3 Snap route to centerline (2D map)      | `lib/core/utils/route_snap.dart` + `ar_navigation_bloc.dart`                  | Shipped                 |
| §6.5 Clamp pose to navmesh                  | `route_segments` from backend used as navmesh; pose snapped per frame         | Shipped                 |
| §10 Fallback (map-centerline only)          | `snapToRouteNotifier` toggle, defaults to map-centerline                      | Shipped                 |
| §6.4 Yaw correction (**manual**)            | `arHeadingOffsetDegNotifier` + slider in `offset_settings_modal.dart`         | Shipped (manual only)   |
| §6.4 Yaw correction (**automatic**)         | —                                                                              | **Missing — gold piece**|
| §6.1 Project to floor plane                 | Path renders at fixed AR y; lateral drift is the actual problem, not vertical | Not needed              |
| §6.2 Wall/mesh boundary detection           | —                                                                              | Skip (see A.5)          |
| Native module API (§11 data model)          | —                                                                              | Skip (see A.5)          |
| ARCore branch                               | App is iOS-only                                                                | N/A                     |

## A.3 The Fix (Minimal, In-Repo)

### A.3.1 Auto-tune `arHeadingOffsetDeg` from corridor direction

The slider in `offset_settings_modal.dart` already feeds `arHeadingOffsetDegNotifier`, which `ArPoseTransformer` already consumes when projecting floorplan → AR. Reuse the same hook — just compute the value automatically.

Algorithm:

1. Maintain a short rolling buffer (e.g. last 3 s) of:
   - ARKit camera world position deltas (`ArPose.position` diffs), and
   - the snapped pose's nearest `route_segment` direction in floorplan space.
2. When the user has walked > 1.5 m total within the window **and** the AR walk vector is roughly parallel to a single segment (dot product > 0.9):
   - `walkDirAr = atan2(Δz, Δx)` from the AR delta.
   - `segDirFloor = atan2(seg.to.y − seg.from.y, seg.to.x − seg.from.x)`.
   - Convert both into the same frame using current `metersPerPixel` and existing `floorplanToArWorld` rotation logic.
   - `yawError = wrap(segDirFloor − walkDirAr)` in degrees.
3. If `|yawError| < 8°`, apply EMA: `offset_new = α·offset_old + (1−α)·(offset_old + yawError)` with `α ≈ 0.85`.
4. Push the result into `LocationConfigService.setArHeadingOffsetDeg(offset_new)` (no UI changes — the slider just moves on its own and the user can override).

Gate the whole thing on a new `autoHeadingCorrectionEnabled` flag in `LocationConfigService` so the user can disable it. Default **on**.

### A.3.2 Snap AR path points on render too

In `ar_navigation_bloc.dart`, before calling `floorplanToArWorld(routePoints[i])`, run each `routePoints[i]` through `snapToRouteNetwork(point, segments)` with **no threshold**. Server route is already on the network, so this is mostly a no-op — but it protects against any future case where a route point sits just off the navmesh.

### A.3.3 Hard cap on per-frame correction

To avoid visible AR jitter when the auto-correction updates, clamp the per-frame delta:

```dart
final delta = (target - current).clamp(-0.5, 0.5); // ° per second
```

at the call site that writes into `arHeadingOffsetDegNotifier`.

## A.4 Expected Result

- Backend `ang` off by 5° → corridor direction observed from user's actual walk pulls offset toward the true value within ~3–5 s of forward motion.
- AR path stops entering walls in straight corridors.
- Turns and junctions are skipped automatically (dot-product gate fails, no update).
- Manual slider still works as override; toggle still works as kill-switch.

## A.5 Explicitly Out of Scope

These boss-doc items are **not** implemented and are not recommended for this app:

| Item                                             | Why skipped                                                                                                                  |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| ARKit scene reconstruction / mesh classification | Requires LiDAR; majority of fleet not LiDAR-equipped; large native Swift work in `ios/Runner/AppDelegate.swift`.             |
| Vertical-plane wall detection                    | Unreliable on white walls, glass, low light (acknowledged in §13). Map centerline is more dependable.                        |
| ARCore Depth API / Android branch                | App is iOS-only.                                                                                                             |
| Floor raycast Y projection                       | Reported symptom is lateral (in-wall), not vertical (floating).                                                              |
| Full native data model (§11)                     | Adds platform-channel surface without solving the heading problem. Revisit only if LiDAR-class scene understanding is added. |

## A.6 Files Touched by the Fix

- `lib/features/ar_navigation/presentation/bloc/ar_navigation_bloc.dart` — add auto-yaw logic in the pose update handler; snap path points before `floorplanToArWorld`.
- `lib/shared/services/location_config_service.dart` — add `autoHeadingCorrectionEnabled` notifier + persist.
- `lib/shared/widgets/offset_settings_modal.dart` — add a toggle row for the new flag.
- `lib/core/utils/route_snap.dart` — no change; reused as-is.

No native iOS changes. No new platform channels. No new backend contract.

## A.7 Testing Checklist

- Inject artificial 2°, 5°, 8° error into `originArPose.eulerAngles.y` at localization; verify auto-correction converges within 5 s of walking ≥ 2 m down a straight corridor.
- Walk a turn: auto-correction must **not** update during the rotation (dot-product gate).
- Disable `autoHeadingCorrectionEnabled`: behaviour reverts exactly to current manual-slider mode.
- Disable `snapToRoute`: blue dot drifts off network (existing behaviour), AR path still benefits from auto-yaw.
- Stationary user: no offset drift over 60 s (walk-distance gate prevents updates).
