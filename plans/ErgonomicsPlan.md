# Plan: GeoAgda ergonomics cleanup

Status: audit done (2026-10-25); steps 1–2 done. Every step must leave `make check`,
`make-everything.sh` and `parsnip/make-everything.sh` green, and gets its own commit.

## Audit findings
- **Dead code.** `GeoAgda.Container.Combinators` is imported nowhere. In `Render.agda`, unused:
  `defaultStyle`, `defaultLineStyle`, `terrainStyle`, `terrainColorByMapIndex`, `featureTerrainColor`,
  `renderFeatureCollection`, `renderTerrainMapSVG`. In `Coordinates.agda`: `viewBoxFromBBox`,
  `defaultWorldViewBox`. Duplicated comment line above `bathymetryColor`.
- **Redundant imports.** `open import Level using (0ℓ)` in ~11 files, almost always unused; many other
  unused names in import lists.
- **Re-implemented stdlib.** `case_of_` defined 3× (`Function.case_of_` exists); `mapM` in `Extraction`
  (use a `Data.List` traversal / `Data.Maybe` applicative); `natToFin10` (10-deep pattern match; stdlib
  has `Fin.fromℕ<`/`Data.Fin.Patterns`, and `guidelines.md` §6 forbids long matches); `scaleFraction`
  (hand-unrolled 4 digits); `formatViewBox` nested `String._++_` (use `String.unwords`/`_++_` chain).
- **Two parallel GeoJSON extractors.** `Extraction.agda` (partial, supports Multi*/GeometryCollection,
  bbox) and `Conformance.agda` (proof-carrying, only Point/LineString/Polygon, drops bbox, never used
  by `Pipeline`). They disagree; the "coherence" test only covers a point fixture.
- **`Render.agda` is a 385-line grab-bag**: style record, palettes, Natural Earth feature-class rules,
  property lookup, geometry/feature rendering. Style rules are a long `if … else if` chain on strings;
  `featureName` is a 9-deep `with` ladder; `record s { fill = … ; stroke = … ; strokeWidth = … }` repeated ~30×.
- **`Coordinates.agda` mixes concerns**: number formatting, projection, path-data formatting, viewBox
  arithmetic, centroid computation.
- **Entry points.** `Pipeline` exposes 5 near-identical functions; `exe/Main.agda` hand-rolls `case_of_`
  and nests `>>`; `exe/Profile.agda` has duplicated imports and qualified-name noise.
- **Docs are stale.** `.agents/rules/guidelines.md` §2 describes a layout that no longer exists
  (`Data/JSON/AST…` now live in `parsnip/`); `GeoAgda.agda` re-exports everything including parsnip.
  `plans/PLAN.md` still lists milestones as if parsnip were in-tree. No README for the app.
- **Repo hygiene.** `earth.jpg`, `lol.jpg`, `test_out.svg`, `example.svg`, `earth.svg` sit in the root
  (ignored, but clutter); `data/` is untracked; `make-everything.sh` writes into the ignored `test/`
  and `Makefile` has no `test`/`everything` target; tests are named `Milestone1..8` rather than by topic.

## Steps (ordered; each small and independently committable)
1. **Dead code and imports** — delete the unused definitions listed above and `Container/Combinators`;
   drop unused `Level`/import names; replace local `case_of_` with `Function.case_of_`.
2. **Stdlib replacements** — `natToFin10`, `scaleFraction`, `mapM`, `formatViewBox`; verify with the
   existing tests plus the fixtures in `Tests/`.
3. **Split `Render.agda`** into `Rendering/SVG/Style.agda` (record + palettes, with a `with-fill`-style
   helper to kill the repeated `record s {…}`), `Rendering/SVG/NaturalEarth.agda` (feature-class rules as
   a table `List (List String × Update)` instead of an `if` chain; `featureName` as a `firstJust` over a
   key list), and `Render.agda` (geometry/feature rendering only).
4. **Split `Coordinates.agda`** into `Projection`, `PathData`, `ViewBox`, `Centroid`.
5. **Unify extraction** — make `Extraction` the single pipeline path, and either extend `Conformance` to
   all geometry types (+ bbox) and prove `validateAndExtract ≡ extractFeatureCollection`, or demote it to
   an optional `Verified` module documented as a subset.
6. **API surface** — collapse `Pipeline` to `geojsonToSVG : SVGStyle → String → Maybe String` (+ the
   `List Char`/`XMLDoc` variants only if used); tidy `exe/Main.agda` (`case_of_`, `do`-style IO via
   `IO.Primitive`/`IO` wrappers); trim `Profile.agda` imports.
7. **Tests** — rename `Milestone*` by topic, move parsnip-only tests to `parsnip/test` (see
   `LibraryPlan.md` step 2), add a `make test` target that builds `Everything`.
8. **Docs/repo** — refresh `guidelines.md` §2 and `PLAN.md`, add a short `README.md` (build, run, layout),
   commit or `.gitignore` `data/`, move generated images out of the root.

## Out of scope / needs a decision
- Splitting `parsnip` into its own repo (`LibraryPlan.md` step 2) — owner's call on timing.
- Changing the rendered SVG output; steps 1–4 must be output-preserving (diff `example.svg` before/after).
