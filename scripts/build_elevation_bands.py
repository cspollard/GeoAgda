#!/usr/bin/env python3
"""
Vectorize a global elevation grid into elevation-band polygons (GeoJSON).

Input is NOAA ETOPO 2022 (60 arc-second, ice-surface GeoTIFF, public domain), downloaded on first use.
Output is a directory with one GeoJSON file per elevation band of the land above sea level,
`elevation_<lower edge in m>.json` (separate files keep each input small for the Agda reader).  Each is a
FeatureCollection holding one MultiPolygon:

    {"featurecla": "Elevation band", "elevation": <m>, "min": <m>, "max": <m>}

The band edges are those of the green palette in GeoAgda.Rendering.SVG.Palette, and `elevation` is a
value inside the band, so the renderer's palette picks the right shade.  `bin/Earth --elevation-bands=DIR`
draws the bands over the land.

    python3 scripts/build_elevation_bands.py [--step N] [--round DEG] [--min-area DEG2] [out-dir]

--step N       average N x N source cells first (1 = full 1' resolution; default 3 = 3')
--round DEG    round coordinates to this many degrees (default 0.01)
--min-area     drop rings smaller than this many square degrees (default 0.003, about 30 km^2)
"""

import argparse
import json
import os
import sys
import urllib.request

import numpy as np
import contourpy
import tifffile

URL = ("https://www.ngdc.noaa.gov/mgg/global/relief/ETOPO2022/data/60s/"
       "60s_surface_elev_gtif/ETOPO_2022_v1_60s_N90W180_surface.tif")
CACHE = os.path.join("data", "cache")
DEM = os.path.join(CACHE, "ETOPO_2022_v1_60s_surface.tif")

# Lower edges of the bands, metres: the thresholds of `greenElevationColor`.
EDGES = [0, 100, 250, 500, 800, 1200, 1800, 2800, 4000]
TOP = 1e9


def download():
    if os.path.exists(DEM):
        return
    os.makedirs(CACHE, exist_ok=True)
    print(f"downloading {URL}", file=sys.stderr)
    urllib.request.urlretrieve(URL, DEM + ".part")
    os.replace(DEM + ".part", DEM)


def load(step):
    z = tifffile.imread(DEM).astype(np.float32)          # 10800 x 21600, north first
    if step > 1:
        h, w = z.shape[0] // step * step, z.shape[1] // step * step
        z = z[:h, :w].reshape(h // step, step, w // step, step).mean(axis=(1, 3))
    h, w = z.shape
    lon = -180 + (np.arange(w) + 0.5) * 360 / w
    lat = 90 - (np.arange(h) + 0.5) * 180 / h
    return lon, lat[::-1], z[::-1]                       # latitude ascending


def ring_area(ring):
    x, y = ring[:, 0], ring[:, 1]
    return 0.5 * abs(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))


def clean(ring, grid):
    """Round to the grid and drop repeated vertices; None if the ring collapses."""
    r = np.round(ring / grid) * grid
    keep = np.ones(len(r), bool)
    keep[1:] = np.any(r[1:] != r[:-1], axis=1)
    r = r[keep]
    if len(r) < 4 or not np.array_equal(r[0], r[-1]):
        return None
    return r


def band_polygons(gen, lo, hi, grid, min_area):
    points, offsets = gen.filled(lo, hi)
    polys = []
    for pts, offs in zip(points, offsets):
        rings = []
        for a, b in zip(offs[:-1], offs[1:]):
            ring = pts[a:b]
            if ring_area(ring) < min_area:
                if not rings:           # outer ring too small: drop the polygon
                    break
                continue
            ring = clean(ring, grid)
            if ring is None:
                if not rings:
                    break
                continue
            rings.append(ring)
        if rings:
            polys.append(rings)
    return polys


def fmt(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def coords(rings):
    return "[" + ",".join("[" + ",".join(f"[{fmt(x)},{fmt(y)}]" for x, y in r) + "]" for r in rings) + "]"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--step", type=int, default=3)
    ap.add_argument("--round", type=float, default=0.01)
    ap.add_argument("--min-area", type=float, default=0.003)
    ap.add_argument("out", nargs="?", default=os.path.join(CACHE, "elevation"))
    args = ap.parse_args()

    download()
    lon, lat, z = load(args.step)
    gen = contourpy.contour_generator(lon, lat, z, fill_type=contourpy.FillType.OuterOffset)
    os.makedirs(args.out, exist_ok=True)
    for lo, hi in zip(EDGES, EDGES[1:] + [TOP]):
        polys = band_polygons(gen, lo if lo > 0 else 1e-3, hi, args.round, args.min_area)
        print(f"{lo:>5} m and up: {len(polys)} polygons", file=sys.stderr)
        if not polys:
            continue
        elev = hi if hi < TOP else lo + 500          # inside the band, as the palette expects
        props = {"featurecla": "Elevation band", "elevation": elev, "min": lo}
        if hi < TOP:
            props["max"] = hi
        geom = '{"type":"MultiPolygon","coordinates":[' + ",".join(coords(p) for p in polys) + "]}"
        feat = '{"type":"Feature","properties":' + json.dumps(props) + ',"geometry":' + geom + "}"
        path = os.path.join(args.out, f"elevation_{lo}.json")
        with open(path, "w") as f:
            f.write('{"type":"FeatureCollection","features":[\n' + feat + "\n]}\n")
        print(f"  wrote {path} ({os.path.getsize(path) / 1e6:.1f} MB)", file=sys.stderr)


if __name__ == "__main__":
    main()
