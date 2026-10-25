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
