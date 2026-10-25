#!/usr/bin/env python3
"""
Lake depth bands from the ETOPO 2022 grid, measured below each lake's own surface.

ETOPO 2022 holds real lake-bottom data for some lakes (Baikal, the Great Lakes, the Caspian, ...) and a
flat surface for the rest.  For every lake of Natural Earth's 10m lakes file this script

  1. takes the grid cells inside the lake outline, shrunk by one cell so shore cells that mix land and water
     do not count;
  2. estimates the lake's surface level as the 95th percentile of those cells;
  3. keeps the lake only if it is one of the well-known lakes in REFERENCE and ETOPO really resolves its
     bottom: the deepest cell must reach at least half of the published maximum depth (so flat lakes,
     and lakes too small for a 1 arc-minute grid, are left out);
  4. vectorizes depth = level - elevation into depth bands, inside the lake.

Output is one GeoJSON FeatureCollection with a MultiPolygon per depth band:

    {"featurecla": "Lake depth", "depth": <m inside the band>, "min": <m>, "max": <m>}

`bin/Earth --lake-depths=FILE` draws it over the lakes layer.

    python3 scripts/build_lake_depths.py [--lakes FILE] [--min-depth M] [--all] [out.json]

The elevation grid is downloaded by scripts/build_elevation_bands.py (run it first, or just `make earth`).
"""

import argparse
import json
import os
import sys

import numpy as np
import contourpy
from matplotlib.path import Path
from scipy.ndimage import binary_erosion

from build_elevation_bands import DEM, CACHE, download, ring_area, clean, fmt

# Published maximum depths (m) of well-known lakes, by Natural Earth name: the sanity check for ETOPO.
REFERENCE = {
    "Lake Baikal": 1642, "Lake Tanganyika": 1470, "Lake Malawi": 706, "Issyk-Kul": 668,
    "Great Slave Lake": 614, "Lake Kivu": 475, "Lake Van": 451, "Great Bear Lake": 446,
    "Lago di Como": 425, "Lake Superior": 406, "Lago di Garda": 346, "Lake Geneva": 310,
    "Lake Michigan": 281, "Lago Titicaca": 281, "Bodensee": 252, "Lake Ontario": 244,
    "Lake Ladoga": 230, "Lake Huron": 229, "Vättern": 128, "Athabasca": 124, "Lake Onega": 120,
    "Lake Turkana": 109, "Lake Victoria": 84, "Lake Sevan": 83, "Lake Erie": 64, "Lake Winnipeg": 36,
}

LAKES = os.path.join("natural-earth-geojson", "10m", "physical", "ne_10m_lakes.json")
# Lower edges of the depth bands, metres: the bands of `depthColor` in GeoAgda.Rendering.SVG.Palette,
# the one depth scale of ocean and lakes.
EDGES = [10, 25, 50, 100, 200, 400, 700, 1000, 1500, 2200, 3300, 5000]
TOP = 1e9
RES = 1 / 60                                      # ETOPO 60 arc-second grid


def polygons(geom):
    if geom is None:
        return []
    if geom["type"] == "Polygon":
        return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon":
        return geom["coordinates"]
    return []


def inside(rings, lon, lat):
    """Cell centres inside the outer ring and outside the holes."""
    xy = np.column_stack([lon.ravel(), lat.ravel()])
    m = Path(np.array(rings[0])).contains_points(xy)
    for hole in rings[1:]:
        m &= ~Path(np.array(hole)).contains_points(xy)
    return m.reshape(lon.shape)


def lake_depth(z, feature):
    """(window of the grid, mask of the lake's inner cells, lon, lat of the window) or None."""
    polys = polygons(feature["geometry"])
    if not polys:
        return None
    pts = np.array([p for poly in polys for p in poly[0]])
    j0 = int((pts[:, 0].min() + 180) / RES) - 2
    j1 = int((pts[:, 0].max() + 180) / RES) + 3
    i0 = int((90 - pts[:, 1].max()) / RES) - 2
    i1 = int((90 - pts[:, 1].min()) / RES) + 3
    i0, j0 = max(i0, 0), max(j0, 0)
    i1, j1 = min(i1, z.shape[0]), min(j1, z.shape[1])
    win = z[i0:i1, j0:j1]
    lon, lat = np.meshgrid(-180 + (np.arange(j0, j1) + 0.5) * RES, 90 - (np.arange(i0, i1) + 0.5) * RES)
    mask = np.zeros(win.shape, bool)
    for poly in polys:
        mask |= inside(poly, lon, lat)
    mask = binary_erosion(mask)
    return win, mask, lon, lat


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lakes", default=LAKES)
    ap.add_argument("--all", action="store_true", help="every lake with relief, not just REFERENCE (exploration)")
    ap.add_argument("--min-depth", type=float, default=15.0)
    ap.add_argument("out", nargs="?", default=os.path.join(CACHE, "lake_depths.json"))
    args = ap.parse_args()

    download()
    import tifffile
    z = tifffile.imread(DEM)
    lakes = json.load(open(args.lakes))["features"]

    # depth grids of all lakes with relief, as separate window rasters
    bands = {lo: [] for lo in EDGES}
    kept = []
    for f in lakes:
        r = lake_depth(z, f)
        if r is None:
            continue
        name = f["properties"].get("name") or "?"
        if not args.all and name not in REFERENCE:
            continue
        win, mask, lon, lat = r
        if mask.sum() < 20:
            if name in REFERENCE:
                print(f"  {name:20s} too small for the grid", file=sys.stderr)
            continue
        cells = win[mask]
        level = np.percentile(cells, 95)
        depth = np.where(mask, np.maximum(level - win, 0), np.nan)
        deepest = np.nanmax(depth)
        ref = REFERENCE.get(name)
        if ref is not None:
            ok = deepest >= ref / 2
            print(f"  {name:20s} surface {level:6.0f} m   ETOPO deepest {deepest:5.0f} m   published {ref:5d} m   "
                  f"{'included' if ok else 'flat in ETOPO: left out'}", file=sys.stderr)
            if not ok:
                continue
        elif deepest < args.min_depth or (cells < level - 3).mean() < 0.3:
            continue
        kept.append((name, level, deepest, int(mask.sum())))
        # contourpy wants y ascending and a masked array for the cells outside the lake
        d = np.ma.masked_invalid(depth[::-1])
        gen = contourpy.contour_generator(lon[0], lat[::-1][:, 0], d, fill_type=contourpy.FillType.OuterOffset)
        for lo, hi in zip(EDGES, EDGES[1:] + [TOP]):
            if deepest < lo:
                break
            pts, offs = gen.filled(lo, hi)
            for p, o in zip(pts, offs):
                rings = []
                for a, b in zip(o[:-1], o[1:]):
                    ring = clean(p[a:b], 0.005)
                    if ring is None:
                        if not rings:
                            break
                        continue
                    rings.append(ring)
                if rings:
                    bands[lo].append(rings)

    feats = []
    for lo, hi in zip(EDGES, EDGES[1:] + [TOP]):
        polys = bands[lo]
        if not polys:
            continue
        depth = hi if hi < TOP else lo + 200      # a value inside the band
        props = {"featurecla": "Lake depth", "depth": int(depth), "min": lo}
        if hi < TOP:
            props["max"] = hi
        coords = "[" + ",".join(
            "[" + ",".join("[" + ",".join(f"[{fmt(x)},{fmt(y)}]" for x, y in r) + "]" for r in rings) + "]"
            for rings in polys) + "]"
        feats.append('{"type":"Feature","properties":' + json.dumps(props) +
                     ',"geometry":{"type":"MultiPolygon","coordinates":' + coords + "}}")
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w") as f:
        f.write('{"type":"FeatureCollection","features":[\n' + ",\n".join(feats) + "\n]}\n")
    print(f"{len(kept)} lakes with relief; wrote {args.out} ({os.path.getsize(args.out) / 1e6:.2f} MB)",
          file=sys.stderr)


if __name__ == "__main__":
    main()
