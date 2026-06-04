#!/usr/bin/env python3
"""
Plot AR navigation debug log.

Usage:
    python3 tools/plot_ar_log.py ar_session.log

Extracts AR_LOG JSON payloads from a Flutter pretty-print log file and
produces matplotlib figures showing:
  - 2D floorplan: route, reference point, transformed user path, heading arrows
  - 3D ARKit world: capture origin, raw AR path, gravity-up reference
  - Heading-over-time: AR yaw, fp heading, sumDeg, derived AR-FP delta
  - sumDeg vs AR heading scatter (rotation consistency check)

Requires: matplotlib, numpy
    pip install matplotlib numpy
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
# pyright: reportUnusedImport=false
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401  # registers '3d' projection

_ = Axes3D  # keep linters happy without losing the side-effect import


AR_LOG_RE = re.compile(r"AR_LOG (\{.*\})\s*$")


def load_entries(path: Path):
    sessions = []
    frames = []
    for line in path.read_text(errors="replace").splitlines():
        m = AR_LOG_RE.search(line)
        if not m:
            continue
        try:
            obj = json.loads(m.group(1))
        except json.JSONDecodeError:
            continue
        if obj.get("t") == "session":
            sessions.append(obj)
        elif obj.get("t") == "frame":
            frames.append(obj)
    return sessions, frames


def signed_delta(a, b):
    d = (a - b + 540.0) % 360.0 - 180.0
    return d


def plot_2d_floorplan(session, frames, ax):
    route = np.array(session.get("routeFp", []), dtype=float)
    ref = session["reference"]
    ax.set_title("Floorplan (image frame: +X right, +Y down)")
    ax.set_aspect("equal")
    if route.size:
        ax.plot(route[:, 0], route[:, 1], "g--o", label="route (FP)",
                markersize=4, alpha=0.7)
    ax.scatter([ref["x"]], [ref["y"]], s=90, c="orange", marker="X",
               label=f"reference ang={ref['heading']:.1f}°", zorder=5)
    rad = np.deg2rad(ref["heading"])
    ax.arrow(ref["x"], ref["y"], 60 * np.cos(rad), 60 * np.sin(rad),
             head_width=18, color="orange", alpha=0.8)
    if frames:
        xs = [f["fp"]["x"] for f in frames]
        ys = [f["fp"]["y"] for f in frames]
        ax.plot(xs, ys, "b-", linewidth=1.2, alpha=0.7,
                label="transformed user (fp.x, fp.y)")
        ax.scatter([xs[0]], [ys[0]], s=60, c="blue", marker="o",
                   label="user start", zorder=4)
        ax.scatter([xs[-1]], [ys[-1]], s=60, c="red", marker="s",
                   label="user end", zorder=4)
        # Heading arrow at last frame
        last = frames[-1]
        fh = last["fp"]["heading"]
        r = np.deg2rad(fh)
        ax.arrow(xs[-1], ys[-1], 80 * np.cos(r), 80 * np.sin(r),
                 head_width=20, color="red", alpha=0.7)
    ax.invert_yaxis()  # image Y down
    ax.legend(loc="best", fontsize=8)
    ax.grid(True, alpha=0.3)


def plot_3d_ar_world(session, frames, ax):
    origin = session.get("origin") or {}
    ax.set_title("ARKit world (worldX East-ish, -worldZ North-ish, worldY Up)")
    ox = origin.get("worldX", 0.0)
    oy = origin.get("worldY", 0.0)
    oz = origin.get("worldZ", 0.0)
    # Plot origin
    ax.scatter([ox], [-oz], [oy], s=100, c="orange", marker="X",
               label=f"capture origin yaw={origin.get('heading', float('nan')):.1f}°")
    # Origin yaw arrow in horizontal plane
    yaw_rad = np.deg2rad(origin.get("heading", 0.0))
    ax.quiver(ox, -oz, oy,
              np.cos(yaw_rad), np.sin(yaw_rad), 0,
              length=0.5, color="orange", alpha=0.8)
    if frames:
        xs = [f["ar"]["wX"] for f in frames]
        zs = [-f["ar"]["wZ"] for f in frames]
        ys = [f["ar"]["wY"] for f in frames]
        ax.plot(xs, zs, ys, "b-", linewidth=1.0, alpha=0.7, label="AR path")
        ax.scatter([xs[0]], [zs[0]], [ys[0]], s=50, c="blue", marker="o",
                   label="path start")
        ax.scatter([xs[-1]], [zs[-1]], [ys[-1]], s=50, c="red", marker="s",
                   label="path end")
        # Heading arrow at last frame
        last = frames[-1]
        hr = np.deg2rad(last["ar"]["heading"])
        ax.quiver(xs[-1], zs[-1], ys[-1],
                  np.cos(hr), np.sin(hr), 0,
                  length=0.5, color="red", alpha=0.8)
    ax.set_xlabel("worldX (m)")
    ax.set_ylabel("-worldZ (m, ~North)")
    ax.set_zlabel("worldY (m, up)")
    ax.legend(loc="best", fontsize=8)


def plot_headings_over_time(session, frames, ax):
    if not frames:
        ax.set_visible(False)
        return
    ts0 = frames[0]["ts"]
    t = np.array([(f["ts"] - ts0) / 1000.0 for f in frames])
    ar_h = np.array([f["ar"]["heading"] for f in frames])
    fp_h = np.array([f["fp"]["heading"] for f in frames])
    sum_h = np.array([f["sumDeg"] for f in frames])
    ref_h = session["reference"]["heading"]
    cap_h = session["origin"]["heading"]
    off = session.get("arHeadingOffsetDeg", 0.0)
    ax.plot(t, ar_h, label="ar.heading (raw ARKit yaw)", alpha=0.8)
    ax.plot(t, fp_h, label="fp.heading (transformed)", alpha=0.8)
    ax.plot(t, sum_h, label="sumDeg (per-frame)", linestyle="--", alpha=0.6)
    ax.axhline(ref_h, color="orange", linestyle=":",
               label=f"reference (API ang) = {ref_h:.1f}°")
    ax.axhline(cap_h, color="green", linestyle=":",
               label=f"origin ar yaw = {cap_h:.1f}°")
    ax.set_xlabel("t (s)")
    ax.set_ylabel("degrees")
    ax.set_title(f"Headings over time (slider offset = {off:.1f}°)")
    ax.legend(loc="best", fontsize=8)
    ax.grid(True, alpha=0.3)


def plot_consistency(frames, ax):
    """sumDeg - currentArHeading should equal fp.heading (mod 360)."""
    if not frames:
        ax.set_visible(False)
        return
    ts0 = frames[0]["ts"]
    t = np.array([(f["ts"] - ts0) / 1000.0 for f in frames])
    ar_h = np.array([f["ar"]["heading"] for f in frames])
    fp_h = np.array([f["fp"]["heading"] for f in frames])
    sum_h = np.array([f["sumDeg"] for f in frames])
    derived_fp = (sum_h - ar_h) % 360.0
    diff = np.array([signed_delta(a, b) for a, b in zip(fp_h, derived_fp)])
    ax.plot(t, diff, "purple", alpha=0.8,
            label="signed( fp.heading − (sumDeg − ar.heading) )")
    ax.axhline(0, color="k", alpha=0.4)
    ax.set_xlabel("t (s)")
    ax.set_ylabel("degrees")
    ax.set_title("Internal consistency (should be ≈ 0)")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)


def print_summary(session, frames):
    print("=" * 60)
    print(f"place    : {session.get('place')}")
    print(f"building : {session.get('building')}")
    print(f"floor    : {session.get('floor')}")
    print(f"mpp      : {session.get('mpp')}")
    print(f"slider   : arHeadingOffsetDeg = {session.get('arHeadingOffsetDeg')}")
    print(f"reference: x={session['reference']['x']:.1f}  "
          f"y={session['reference']['y']:.1f}  "
          f"heading={session['reference']['heading']:.2f}°  (API ang)")
    o = session.get("origin")
    if o:
        print(f"origin   : worldX={o['worldX']:.3f}  worldY={o['worldY']:.3f}  "
              f"worldZ={o['worldZ']:.3f}  yaw={o['heading']:.2f}°  "
              f"conf={o['confidence']:.2f}")
    route = session.get("routeFp", [])
    print(f"route    : {len(route)} waypoints")
    print(f"frames   : {len(frames)}")
    if frames:
        first, last = frames[0], frames[-1]
        dt = (last["ts"] - first["ts"]) / 1000.0
        print(f"duration : {dt:.2f} s")
        print(f"AR yaw   : first={first['ar']['heading']:.1f}°  "
              f"last={last['ar']['heading']:.1f}°")
        print(f"fp heading: first={first['fp']['heading']:.1f}°  "
              f"last={last['fp']['heading']:.1f}°")
        print(f"travel   : last travelM = {last['travelM']:.2f} m")
    print("=" * 60)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 plot_ar_log.py <ar_session.log>")
        sys.exit(1)
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"File not found: {path}")
        sys.exit(1)
    sessions, frames = load_entries(path)
    if not sessions:
        print("No session header found in log.")
        sys.exit(1)
    # Use last session header (if multiple)
    session = sessions[-1]
    print_summary(session, frames)

    fig = plt.figure(figsize=(15, 10))
    ax1 = fig.add_subplot(2, 2, 1)
    plot_2d_floorplan(session, frames, ax1)
    ax2 = fig.add_subplot(2, 2, 2, projection="3d")
    plot_3d_ar_world(session, frames, ax2)
    ax3 = fig.add_subplot(2, 2, 3)
    plot_headings_over_time(session, frames, ax3)
    ax4 = fig.add_subplot(2, 2, 4)
    plot_consistency(frames, ax4)
    fig.tight_layout()

    out_png = path.with_suffix(".png")
    fig.savefig(out_png, dpi=130)
    print(f"Saved figure: {out_png}")
    plt.show()


if __name__ == "__main__":
    main()
