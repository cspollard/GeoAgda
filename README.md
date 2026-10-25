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
| `--borders` | draw country boundaries (off by default) |
| `--country-names` | label countries (off by default) |
| `--precision=DEG` | round coordinates to this grid (default `0.01`) |
| `--thin=DEG` | drop bathymetry vertices closer than this (default `0.3`; `0` keeps all) |

It takes under a minute and about 2.5 GB of memory (the 10m bathymetry files are up to 23 MB each; every
layer is read, reduced and dropped before the next, so the peak is the largest single file). Coordinates
are rounded to 0.01°, and the bathymetry is thinned so that vertices are at least 0.3° apart
(`GeoAgda.Model.GeoJSON.Simplify`); both are configurable. Open `earth.svg` in a browser.

To change the map, edit the recipe in `src/GeoAgda/Compose/Earth.agda`: a list of `Group`s of `Layer`s, each
naming a source file and a function from source feature to composite feature (or `nothing` to drop it).
`scripts/build_earth_composite.py` is the earlier Python version; it is superseded by `bin/Earth`.

Possible improvements: also write the composite as GeoJSON (needs a `Feature → JSON` encoder; it would be the
natural place for an `extract (encode fc) ≡ just fc` lemma), and a streaming tokenizer to lower the peak memory.
