# Auto Heading Correction

Live, walk-driven correction of the AR ↔ floorplan heading offset.
Hides the 2–5 degree error coming from the backend `ang` / origin ARKit
yaw so the AR path stops drifting into walls in long corridors.

---

## 1. Why this exists

The AR overlay is built by rotating the route polyline from floorplan
pixel space into ARKit world space:

```
sumHeadingDeg = reference.heading
              + originArPose.heading
              + arHeadingOffsetDeg
```

`reference.heading` comes from the backend localization (`ang`).
`originArPose.heading` is the ARKit yaw at the moment we captured the
localization frame.

Neither is reliably accurate. Even a small error in either gets baked
into `sumHeadingDeg` for the rest of the navigation session. The AR
overlay then rotates around the user by that error angle, and lateral
drift grows linearly with corridor length:

```
lateral_drift = corridor_length × tan(θ)

θ = 3°, length = 12 m → drift ≈ 0.63 m  → inside the wall
θ = 5°, length = 12 m → drift ≈ 1.05 m  → clearly off-route
```

The snap-to-route feature hides this on the 2D map (it projects the
blue dot onto the nearest navmesh edge), but it cannot help the AR
scene — those SCNNodes are anchored in world space using the wrong
angle.

The fix this feature ships drives `arHeadingOffsetDeg` itself, which
short-circuits the cumulative error at the source.

---

## 2. What it does at runtime

Every pose frame:

1. Read `localizedPose` from `ArPoseTransformer.transform(...)`. This
   is the **unsnapped** floorplan pose (before snap-to-route).
2. Read the raw AR-world position (`worldX`, `worldZ`) from `ArPose`.
3. Push both into a 3 second rolling buffer, keyed by frame timestamp.
4. Trim entries older than 3 s.

Then the corrector decides whether to nudge the offset:

| Gate           | Threshold                              | Why                                              |
| -------------- | -------------------------------------- | ------------------------------------------------ |
| Walk distance  | AR walk ≥ 1.5 m within window          | A short shuffle is not a heading signal.         |
| Parallelism    | `|cos(walk, segment)| ≥ 0.9`           | Skip turns, junctions, oblique crossings.        |
| Error ceiling  | `|yawError| ≤ 8°`                      | Anything larger is probably a wrong segment.     |
| Per-call delta | `|delta| ≤ 0.5°` per call              | Hard cap on visible AR jitter.                   |

When all gates pass:

```
observed_dir   = atan2(Δy_fp, Δx_fp)         // observed corridor direction
segment_dir    = atan2(Δy_seg, Δx_seg)        // nearest route_segment direction
yawError       = signed_delta(observed, oriented_segment_dir)
nudge          = (1 − α) × yawError            // α = 0.85, EMA
clamped        = clamp(nudge, ±0.5°)
new_offset     = current_offset + clamped
```

`new_offset` is pushed into `LocationConfigService.setArHeadingOffsetDeg(...)`
— the same hook the manual slider writes to. The next frame re-renders
with the updated angle.

---

## 3. Edge cases that are handled

- **Reverse walking** (user walking the corridor the wrong way): the
  segment direction is flipped 180° when the walk-vs-segment dot
  product is negative, so the corrector never tries to inject a
  half-turn.
- **Stationary user**: the walk-distance gate fails, so no update.
  The current offset is preserved as-is.
- **Junctions and corners**: the parallelism gate fails when the user
  is mid-turn; correction simply skips that window and resumes on the
  next straight segment.
- **Snap-to-route disabled**: still works. The corrector consumes the
  unsnapped pose explicitly so it doesn't depend on the snap toggle.
- **Manual override**: the user can drag the slider mid-session. Last
  writer wins per frame; subsequent auto-updates will resume from the
  manual value and EMA it back toward the corridor-derived target.

---

## 4. User-visible behaviour

- The rotation slider in **Offset Settings** moves on its own as you
  walk a straight corridor. Convergence: ~3–5 s of forward motion in
  a clear hallway.
- A new toggle row in **Offset Settings**, "Auto heading correction"
  (default **on**), kills the feature. Disabled → behaviour is exactly
  the same as before the feature shipped (manual slider only).
- The reset button on the rotation slider still zeroes the offset.

---

## 5. Files

| File                                                                                                | Role                                                                                       |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `lib/features/ar_navigation/domain/services/heading_auto_corrector.dart`                            | Pure-logic service. Rolling buffer, gates, EMA, clamp. No Flutter deps beyond `Offset`.    |
| `lib/features/ar_navigation/presentation/bloc/ar_navigation_bloc.dart`                              | Instantiates the corrector, resets it on `StartArNavigation`, calls `observe(...)` on each |
|                                                                                                     | pose frame, pushes suggestions into `LocationConfigService`.                               |
| `lib/core/utils/route_snap.dart`                                                                    | Reused for the nearest-segment lookup inside the corrector.                                |
| `lib/shared/services/location_config_service.dart`                                                  | New `autoHeadingCorrectionNotifier` (persisted under `auto_heading_correction`,            |
|                                                                                                     | default `true`).                                                                           |
| `lib/shared/widgets/offset_settings_modal.dart`                                                     | New `_AutoHeadingRow` toggle, bound to the notifier.                                       |

The corrector also nudges `_handleArOverlay` to run each path vertex
through `snapToRouteNetwork` before `floorplanToArWorld`. Backend route
points already sit on the navmesh, so usually a no-op — it just
prevents a future stray vertex from leaking off the corridor.

---

## 6. Tunable parameters

All defined in `HeadingAutoCorrector`'s constructor. Tweak with care.

| Parameter              | Default            | Effect of increasing                                  |
| ---------------------- | ------------------ | ----------------------------------------------------- |
| `bufferWindow`         | 3 s                | Smoother trajectory, slower reaction to real changes. |
| `minimumWalkMeters`    | 1.5 m              | Fewer false positives, but converges later.           |
| `parallelDotThreshold` | 0.9 (≈ 25°)        | Stricter parallelism gate; fewer updates in curves.   |
| `maxCorrectionDeg`     | 8°                 | More tolerant of large errors but riskier.            |
| `emaAlpha`             | 0.85               | Slower convergence, less overshoot.                   |
| `maxPerCallDeltaDeg`   | 0.5°               | Smoother slider movement, slower convergence.         |

---

## 7. Tradeoffs

**Pros**

- Zero native code. Pure Dart on top of data the bloc already had.
- Works on every device (no LiDAR required).
- Reuses the existing `arHeadingOffsetDeg` pipeline, so the manual
  slider and the auto-corrector share one source of truth.
- Reversible via toggle, persisted per user.

**Cons**

- Requires the user to walk before it can fix anything. A stationary
  user with a bad initial offset sees no correction.
- Open areas and intersection-heavy floors give fewer parallel-walk
  windows, so convergence takes longer there.
- If the backend route ever sits parallel-but-offset from the real
  corridor, the corrector will lock onto the wrong angle. Mitigation:
  rely on the wall-detection branch (`feat/ar-wall-detection`) which
  uses LiDAR mesh classification instead of walk direction.

---

## 8. Testing checklist

1. **Convergence**: inject a 2° / 5° / 8° error into `originArPose.eulerAngles.y`
   at localization time. Walk ≥ 2 m down a clear corridor. The slider
   in Offset Settings should converge onto the true correction within
   3–5 s.
2. **Turns**: walk a 90° turn. The slider must not change during the
   rotation; the parallel-dot gate is responsible.
3. **Stationary**: stand still for 60 s. The slider must not drift.
4. **Toggle off**: flip "Auto heading correction" off mid-session.
   Behaviour should immediately revert to manual-slider-only mode.
5. **Reverse walk**: walk a corridor backwards. No half-turn should be
   injected; the corrector should still converge correctly.
6. **Snap toggle independence**: turn off "Snap to route" and repeat
   test 1 — auto-heading still functions, the blue dot just doesn't
   ride the navmesh.

---

## 9. Related

- `path_docs.md` — original boss document plus Appendix A explaining
  why the wider wall-detection / mesh proposal was scoped down to this
  walk-driven implementation.
- `docs/snap-to-route.md` — the 2D map-side fix that this feature
  complements.
- `feat/ar-wall-detection` branch — adds a parallel LiDAR-based
  corrector that does not require user motion. Stacked on top of this
  branch.
