# GeoAgda

Verified GeoJSON → SVG in Agda (`--safe --cubical-compatible`). Natural Earth data is the target input.

- JSON/XML/SVG parsing and printing, with proved round trips, lives in the `parsnip/` submodule.
- `GeoAgda.Model.GeoJSON.*` extracts a typed GeoJSON model from JSON. `Conformance`/`Properties`/`Validate`
  give a declarative notion of validity and prove that extraction is sound and complete for it.
- `GeoAgda.Rendering.SVG.*` renders the model; `GeoAgda.Pipeline` ties it together.

See `.agents/rules/guidelines.md` §2 for the module map and `plans/` for design notes.

## Build

Needs Agda ≥ 2.7 with `standard-library` and `agda-categories` registered in `~/.agda/libraries`, and the
submodules (`git submodule update --init`; the Natural Earth data submodule is optional).

```
make check      # typecheck exe/Main.agda and everything it imports
make test       # typecheck every module under src/, including Tests/
make            # compile bin/Main
./bin/Main [in.geojson [out.svg]]   # defaults: data/fixtures/natural_earth_sample.geojson → example.svg
```

`parsnip/make-everything.sh` checks the library alone.

## Earth map with elevation

The default terrain style tints features by `elevation` and `featurecla`. The map is composed in Agda
(`GeoAgda.Compose.Earth`) straight from the Natural Earth submodule, with no intermediate file:
bathymetry contours, land, hypsometric regions with elevations, summits, glaciers, lakes, rivers, borders and
country labels.

```
git submodule update --init natural-earth-geojson    # the data (large)
make earth                                           # builds bin/Earth and writes earth.svg
bin/Earth [options] [data-dir [out.svg]]             # defaults: natural-earth-geojson, earth.svg
```

Options (`bin/Earth --help`; `GeoAgda.Compose.Options`):

| option | effect |
| --- | --- |
| `--land=elevation` (default) | land in shades of green by elevation |
| `--land=flat` | land in one colour, no elevation |
| `--land=areas` | named plains, deserts and ranges with hypsometric tints, plus peaks and labels |
| `--resolution=10m\|50m\|110m` | Natural Earth scale of land, lakes, rivers, borders and country names (default `10m`, like the bathymetry) |
| `--elevation-bands=DIR` | draw the ETOPO band files in `DIR` (see below): ocean depth in place of Natural Earth's bathymetry, and with `--land=elevation` land elevation in place of the named landform regions |
| `--lake-depths=FILE` | shade lake depth from the file made by `scripts/build_lake_depths.py` |
| `--borders` | draw country boundaries (off by default) |
| `--country-names` | label countries (off by default) |
| `--precision=DEG` | round coordinates to this grid (default `0.01`); `0` keeps every vertex exactly as read, for land and water, and ignores `--thin` |
| `--thin=DEG` | drop Natural Earth bathymetry vertices closer than this (default `0.3`; `0` keeps all); not used with `--elevation-bands` |

It takes under a minute and about 2.5 GB of memory (the 10m bathymetry files are up to 23 MB each; every
layer is read, reduced and dropped before the next, so the peak is the largest single file). Coordinates
are rounded to 0.01°, and the bathymetry is thinned so that vertices are at least 0.3° apart
(`GeoAgda.Model.GeoJSON.Simplify`); both are configurable. Open `earth.svg` in a browser.

### Real elevation data

Natural Earth ships no elevation raster, so `--land=elevation` alone shades land by the named landform
regions (coarse). `scripts/build_elevation_bands.py` vectorizes NOAA ETOPO 2022 (1 arc-minute ice surface,
downloaded once to `data/cache`, about 470 MB) into one GeoJSON file per band: land elevation bands with
the edges of the green palette, and ocean depth bands with the edges of `depthColor` (they replace Natural
Earth's bathymetry contours, and share a grid with the land so the coastlines agree); it needs `numpy`, `contourpy` and `tifffile`. `make elevation` runs it and `make earth`
passes the result to `bin/Earth`:

```
python3 scripts/build_elevation_bands.py [--step N] [--round DEG] [--min-area DEG2] [out-dir]
bin/Earth --elevation-bands=data/cache/elevation
```

`--step 3` (default) averages 3×3 cells, giving 3′ bands; `--step 1` is the full 1′ grid but several times
larger. The default bands total about 150 MB (56 MB land, 92 MB ocean); the SVG is about 190 MB.

### Lake depths

`scripts/build_lake_depths.py` measures lake depth below each lake's own surface from the same ETOPO grid and
writes depth bands for the lakes it resolves; `bin/Earth --lake-depths=data/cache/lake_depths.json` shades
them (`make earth` does both). ETOPO 2022 has real lake bottoms for only a few lakes: Baikal and Lakes
Superior, Michigan, Huron, Erie and Ontario. The script checks 26 well-known lakes (table `REFERENCE`) and keeps
those whose deepest cell reaches half the published maximum depth. Every other lake stays in the neutral
lake colour (the surface colour of the depth scale). Lakes and the ocean share one depth scale,
`depthColor` in `GeoAgda.Rendering.SVG.Palette`, whose bands grow geometrically with depth.

To change the map, edit the recipe in `src/GeoAgda/Compose/Earth.agda`: a list of `Group`s of `Layer`s, each
naming a source file and a function from source feature to composite feature (or `nothing` to drop it).
`scripts/build_earth_composite.py` is the earlier Python version; it is superseded by `bin/Earth`.

Possible improvements: also write the composite as GeoJSON (needs a `Feature → JSON` encoder; it would be the
natural place for an `extract (encode fc) ≡ just fc` lemma), and a streaming tokenizer to lower the peak memory.
