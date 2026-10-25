#!/usr/bin/env python3
"""
Vectorize a global elevation grid into land elevation bands and ocean depth bands (GeoJSON).

Input is NOAA ETOPO 2022 (60 arc-second, ice-surface GeoTIFF, public domain), downloaded on first use.
Output is a directory with one GeoJSON file per band (separate files keep each input small for the Agda
reader), each a FeatureCollection holding one MultiPolygon:

    elevation_<lower edge in m>.json   land above sea level
        {"featurecla": "Elevation band", "elevation": <m>, "min": <m>, "max": <m>}
    bathymetry_<lower edge in m>.json  ocean below sea level
        {"featurecla": "Bathymetry", "depth": <m>, "min": <m>, "max": <m>}

The band edges are those of the palettes in GeoAgda.Rendering.SVG.Palette, and `elevation` / `depth` is a
value inside the band, so the renderer's palette picks the right shade.  `bin/Earth --elevation-bands=DIR`
draws them: the land bands for --land=elevation, the ocean bands in place of Natural Earth's bathymetry.
Land and ocean come from one grid, so their coastlines agree.

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
# Lower edges of the ocean depth bands, metres below sea level: the bands of `depthColor`.
DEPTH_EDGES = [0, 10, 25, 50, 100, 200, 400, 700, 1000, 1500, 2200, 3300, 5000]
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


def write_bands(gen, edges, out, prefix, props, args):
    """One file per band [lo, hi): `<prefix>_<lo>.json` holding a single MultiPolygon feature."""
    for lo, hi in zip(edges, edges[1:] + [TOP]):
        polys = band_polygons(gen, lo if lo > 0 else 1e-3, hi, args.round, args.min_area)
        print(f"{prefix} {lo:>5} m and up: {len(polys)} polygons", file=sys.stderr)
        if not polys:
            continue
        p = props(lo, hi)
        geom = '{"type":"MultiPolygon","coordinates":[' + ",".join(coords(q) for q in polys) + "]}"
        feat = '{"type":"Feature","properties":' + json.dumps(p) + ',"geometry":' + geom + "}"
        path = os.path.join(out, f"{prefix}_{lo}.json")
        with open(path, "w") as f:
            f.write('{"type":"FeatureCollection","features":[\n' + feat + "\n]}\n")
        print(f"  wrote {path} ({os.path.getsize(path) / 1e6:.1f} MB)", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--step", type=int, default=3)
    ap.add_argument("--round", type=float, default=0.01)
    ap.add_argument("--min-area", type=float, default=0.003)
    ap.add_argument("out", nargs="?", default=os.path.join(CACHE, "elevation"))
    args = ap.parse_args()

    download()
    lon, lat, z = load(args.step)
    os.makedirs(args.out, exist_ok=True)
    fill = contourpy.FillType.OuterOffset

    def land_props(lo, hi):
        # a value inside the band, as the palette expects
        p = {"featurecla": "Elevation band", "elevation": hi if hi < TOP else lo + 500, "min": lo}
        return p if hi == TOP else {**p, "max": hi}

    def ocean_props(lo, hi):
        # `depthColor` colours a band by `d <= upper edge`
        p = {"featurecla": "Bathymetry", "depth": hi if hi < TOP else lo + 1000, "min": lo}
        return p if hi == TOP else {**p, "max": hi}

    write_bands(contourpy.contour_generator(lon, lat, z, fill_type=fill), EDGES, args.out,
                "elevation", land_props, args)
    write_bands(contourpy.contour_generator(lon, lat, -z, fill_type=fill), DEPTH_EDGES, args.out,
                "bathymetry", ocean_props, args)


if __name__ == "__main__":
    main()
