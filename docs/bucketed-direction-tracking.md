# Bucketed-Direction Tracking ("Push the Train on Tracks")

A new tracking mode for the indoor navigation app. Instead of trying
to render an AR line that perfectly matches reality, this mode turns
the phone's AR sensor into a coarse step counter + compass and pushes
the user dot along the route on the map view.

This is the "Solution 2" approach discussed in the meeting with JR.

---

## The problem we are solving

The current AR-line approach demands a near-perfect alignment between
two things:

1. Where the floorplan says the user is.
2. What direction the phone's AR sensor reports.

Both numbers carry a few degrees of error. When the rotation is off by
even three or four degrees, the projected line drifts visibly into
walls as the user walks. We can keep refining alignment, but it is a
hard problem because the error sources are partly outside our control
(magnetometer noise, building-side server estimates, indoor
electromagnetic interference).

## The idea in one paragraph

We stop demanding pixel accuracy. The user is walking down a corridor,
not free-roaming a field — there are only a handful of meaningful
directions they can actually go (forward, back, side hallway). So
instead of asking "what exact heading does the sensor say," we ask
"which of a few coarse compass buckets is the user moving in?" Once
we know that, we step the dot on the map by however many metres the
sensor says they walked, in that bucket's direction, and snap the
result to the nearest path line on the floorplan.

A bucket spans 45° or 22.5°. Any sensor error smaller than the bucket
width is silently absorbed — we still pick the same bucket. The user
dot still moves in the correct direction, by the correct number of
metres.

## Compass buckets

In the default 4-bucket setup, every reading is rounded to one of:

- **East** — angles between 315° and 45°
- **South** — angles between 45° and 135°
- **West** — angles between 135° and 225°
- **North** — angles between 225° and 315°

If 4 is too coarse for a building whose corridors don't line up
neatly with the cardinal directions, the user can switch to 8 buckets
(adds NE, SE, SW, NW). Both options are exposed in the settings
sheet.

## What direction we actually measure

We do not use the direction the phone is pointing. People hold the
phone in their hand, glance at it sideways, walk backwards, look at
the ceiling — the phone facing has nothing reliable to do with where
the body is going.

We use the **direction of travel** instead. We sample the user's
position twice in quick succession, draw an arrow from where they
were to where they are now, and that arrow is the direction. This is
robust to the phone being held any which way.

## Step by step (what happens every frame)

1. The phone reports its current position in the AR session's
   coordinate space.
2. We subtract the previous position. The difference is the user's
   walk vector since the last frame.
3. We measure the length of that vector. That is the distance walked
   in metres. If it is less than 10 cm we treat the user as standing
   still and skip the rest — this keeps sensor jitter from creating
   phantom motion when the user is not really moving.
4. We measure the angle of that walk vector and convert it into the
   floorplan's compass system.
5. We round the angle to the nearest bucket centre.
6. We take the dot's previous position on the floorplan and advance
   it by the walked distance in the bucketed direction.
7. We snap the result onto the nearest path line on the navmesh
   (within a two-metre tolerance), so the dot stays on a walkable
   corridor.
8. That snapped position is the new location of the user dot. We
   show it on the map.

The AR camera line (the cylinder line we used to draw on top of the
camera image) is cleared the moment this mode is on. Pixel accuracy
is no longer the goal, so the line would only mislead.

## Why this is robust to sensor error

Suppose the user is walking east, the true direction is 0°, and the
sensor says 8°. With the line-based approach, the rendered path tilts
8° off and after twelve metres the line is more than a metre to the
side of the actual corridor.

With bucketed tracking, 8° is still inside the "East" bucket
(–45° to +45°). The dot is advanced exactly east by however many
metres the sensor measured. The next frame, again exactly east.
After twelve metres, the dot is twelve metres east on the corridor —
exactly where the user is. The 8° error never accumulates into a
visible lateral drift because we never rotated the step by 8°.

The bucket width is the engineered margin of safety. Choose 4 buckets
for a building with simple right-angle corridors; 8 if there are
30°/60° hallway angles to capture.

## When this mode is helpful and when it is not

**Helpful**

- Long straight corridors with right-angle turns.
- Buildings where the sensor heading is unreliable (deep interiors,
  electromagnetic interference, problematic magnetometer
  calibration).
- Users who do not need a vertical AR overlay — directional voice
  guidance plus a map view is enough.

**Less helpful**

- Open spaces with no corridor structure (atriums, large rooms).
  Without a path to snap onto, the dot's position is still as good
  as the bucket but the on-map experience is weaker.
- Buildings where corridors run at unusual diagonals not captured by
  4 or 8 buckets. Adding a 16-bucket option is a future possibility,
  but at 16 buckets the safety margin per bucket is back down to
  ±11°, which is close to the sensor error we were trying to absorb.

## Trade-offs vs. the AR-line approach

| Property                                | AR-line approach          | Bucketed mode                          |
| --------------------------------------- | ------------------------- | -------------------------------------- |
| Pixel accuracy of overlay               | Required                  | Not used                               |
| Tolerance for sensor heading error      | A couple of degrees       | ±45° (4-bucket) or ±22.5° (8-bucket)  |
| Primary UI                              | AR camera + overlay line  | Top-down map with moving user dot      |
| Failure mode                            | Line drifts into walls    | Dot occasionally snaps to wrong path   |
| Off-route detection                     | Visual cue + path tracker | Path tracker only                      |
| Distance reporting                      | Sensor-derived (metres)   | Sensor-derived (metres) — same source |

## Where the user controls it

Open the **Offset Settings** sheet (the existing slider sheet). At the
bottom there is a new switch called **"Bucketed direction (train on
tracks)"**. Flipping it on switches the user dot's behaviour to the
bucketed model and hides the AR overlay. Below the switch is a small
chip selector that lets the user choose between 4 and 8 buckets.

The existing **rotation slider** (manual heading adjust) and
**auto-heading-correction** toggle still exist and still work in
their normal mode. In bucketed mode, auto-correction is suppressed
automatically because the bucket already absorbs the error the
auto-correction would have chased.

## A simple analogy

Think of the user dot as a train and the corridor lines as tracks.
The phone is no longer trying to draw a real-time picture of which
way the train is pointing. It is just sensing "the train moved
forward by three metres along its current track." The system pushes
the train three metres along the corridor on the map. Whether the
sensor's heading was a few degrees off doesn't matter — the track
itself dictates which way "forward" means, and the bucket picks the
right track at each junction.

That is the entire idea. The rest is just the bookkeeping needed to
keep the train on the right track when several corridors branch off.

## Next steps after the prototype

1. Field-test in a known building. Walk a known route with the
   bucketed mode on. Watch how the user dot moves vs. the path.
2. Compare 4 vs. 8 buckets in the same building. If 4 looks fine,
   leave 4 as default. If diagonals are common, default to 8.
3. Decide whether the AR overlay should be removable entirely in
   the final shipping build, or kept as an opt-in for the case
   where the heading is known to be accurate.
4. Confirm voice/audio guidance still fires correctly off the
   bucketed dot's progress (it should — the same tracker that
   drives off-route detection and waypoint advance still reads the
   dot's position on the floorplan).
