# Auto Heading Correction — Simple Explanation

The plain-language version. For the math-and-files-and-tunables version,
see `docs/auto-heading-correction.md`.

---

## The problem

When the app starts navigation, it asks two questions:

1. "Where am I?" → backend says: *"you're at floorplan point X, facing 90°"*
2. "Which way is ARKit facing right now?" → ARKit says: *"I'm pointing 12°"*

The app adds those two numbers — **that's the angle it uses to rotate the
AR path** from floorplan space into the real world.

Now the bug: both numbers can be **wrong by 2–5°**. Backend isn't perfect.
ARKit compass drifts. Wrong + wrong = AR path is rotated wrong = it sits at
an angle in the corridor = it walks straight into the wall the further you
go.

---

## The fix in one sentence

**Watch which way the user is actually walking. Compare it to which way
the corridor actually goes. If they don't match, that mismatch IS the
error. Rotate the path by that mismatch. Done.**

---

## How it knows

The app already has two pieces of data every frame:

- **Where the user IS on the floorplan** (the blue dot position).
- **The route segments** (lines drawn on the navmesh — these ARE the
  corridors).

So:

```
Step 1: Remember user's position over the last 3 seconds.
Step 2: Did they walk at least 1.5 m in a straight line?
        No  → wait, do nothing.    (standing still tells us nothing)
        Yes → continue.
Step 3: Draw an arrow from where they were 3 s ago → where they are now.
        That arrow = "direction user is actually walking".
Step 4: Find which corridor (route_segment) they're walking on.
        That corridor's line = "direction corridor actually goes".
Step 5: Are these two arrows roughly parallel?
        No  → they're at a turn or junction. Do nothing.
        Yes → continue.
Step 6: Measure the angle between them. That's the ERROR.
Step 7: Push that small angle into the rotation slider.
        Slowly (max 0.5° per frame so AR doesn't jitter).
Step 8: Next frame, the AR path is rotated 0.5° more correctly.
        After ~3–5 seconds of walking, the path is fully aligned with
        the real corridor.
```

---

## Why it works

Imagine the AR path is rotated wrong by 5°:

- You're walking down a real corridor that goes **east**.
- But on your phone screen, the blue dot is moving at a 5° angle (because
  the rotation is wrong).
- App says: *"Hmm — dot is moving 5° off the corridor direction. The
  corridor doesn't bend. So the rotation must be 5° wrong. Subtract 5°."*
- Next moment, dot moves perfectly down the corridor on screen. The real
  AR path now sits correctly in the real corridor.

The corridor is the **ground truth** (you can't walk through walls in
real life). So the corridor wins. Everything else gets adjusted to match
it.

---

## The gates (why it doesn't break)

Without these, it would do dumb things:

| Gate              | Without it would do                                            |
| ----------------- | -------------------------------------------------------------- |
| Need 1.5 m walk   | Tiny jitter → tiny "error" → constant wrong updates            |
| Need parallel     | At a 90° turn, would think the corridor is 90° wrong           |
| Error < 8°        | If standing on the wrong corridor entirely, would lock in nonsense |
| Max 0.5° per step | Slider would jump wildly; AR path visibly snaps                |

---

## What the user sees

- Walk down a hallway for a few seconds.
- The little rotation slider in **Offset Settings** moves on its own.
- The AR path settles into the middle of the corridor.
- Standing still or turning → slider doesn't move (it waits for the user
  to walk straight again).
- Don't like it? Flip the toggle off. The slider becomes manual-only
  again.

---

## That's it

One sentence again: **the corridor is the truth, the user's walk
reveals it, the slider adjusts to match it.**
