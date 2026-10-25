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

The terrain style (the default) tints features by `elevation` and by `featurecla`, so a layered
physical map needs a composite GeoJSON file. `scripts/build_earth_composite.py` builds one from the
Natural Earth submodule: bathymetry contours, land, hypsometric regions with elevations, spot summits,
glaciers, lakes, rivers, borders and country labels.

```
git submodule update --init natural-earth-geojson          # the data (large)
mkdir -p data/fixtures
python3 scripts/build_earth_composite.py                   # run from the repo root
make                                                       # build bin/Main if you haven't
./bin/Main data/fixtures/earth_physical_topography.geojson earth.svg
```

The script reads `natural-earth-geojson/` and writes `data/fixtures/earth_physical_topography.geojson`
(paths are relative, so run it from the repository root). If that file already exists, its
bathymetry layer is reused instead of rebuilt from the 10m files. Open `earth.svg` in a browser.
To restyle, pass another `SVGStyle` to `GeoAgda.Pipeline.geojsonToSVG`; the default is
`defaultTerrainStyle` (`GeoAgda.Rendering.SVG.Style`).
