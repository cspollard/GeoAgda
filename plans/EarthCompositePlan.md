# Plan: build the earth-with-elevation map in pure Agda

Status: proposal (2026-10-25). Nothing implemented. Replaces `scripts/build_earth_composite.py`.

## What the Python script does
Nine layers from Natural Earth, concatenated into one `FeatureCollection` (bottom to top): bathymetry contours,
land (`elevation` 50), topographic regions (110m, then 50m for names missing from the 110m set) with elevations
from a hard-coded name table (~45 entries) or a per-class default, ten named summits, glaciers, lakes, rivers,
land borders, and country-label points for countries with `LABELRANK ≤ 2`. Per feature it: filters, rewrites
`properties` (`featurecla`, `name`, `elevation`, `LABELX/LABELY`, `scalerank`), ASCII-folds and title-cases names,
rounds coordinates to 2 decimals, and computes a mean-of-vertices centroid.

## Findings (measured, `exe/Profile.agda`, parse + extract)
| input | size | time | peak RSS |
|---|---|---|---|
| 110m regions | 6.6 MB | 2.9 s | 0.75 GB |
| 50m regions | 10.4 MB | 3.8 s | 1.1 GB |
| all other small layers | < 1 MB each | < 1 s | small |
| 10m bathymetry, 7 files used | 65 MB total | 26 s | 2.0 GB (largest file) |

- Reading everything is feasible: ~35 s, and the peak is that of the single largest file **if each file is parsed,
  reduced and dropped before the next** (the AST of a file must not be retained).
- **The existing fixture's bathymetry is not reproducible from the script.** It has 340 features / 131 k vertices,
  but the 10m sources have 1.43 M vertices; the script's fallback only rounds. Snapping to 0.1° and dropping
  repeats still leaves 591 k. The fixture was decimated by some earlier, unrecorded step (~11×).
  Any rebuild, in Python or Agda, needs an explicit simplification step — this is the real design question.
- Merging in memory is cheap: the merge is list concatenation of `Feature`s. What costs is parsing the inputs and
  (for the output) vertex count: the 131 k-vertex fixture renders in ~0.6 s, ~1.4 M vertices would be an ~15–60 MB
  SVG. So simplify *before* retaining, then merge, then render directly — no intermediate GeoJSON file is needed.
- Not a problem here: writing a GeoJSON file via `printJSON` (children are `Fin n → _`, printing a node with n
  children is O(n²); fine for ~700 features but not for 10⁴-vertex rings — another reason to render directly).

## Difficulty, by piece
| piece | effort | notes |
|---|---|---|
| layer recipe as data (sources, filters, elevation table, peak list) | easy | a `Layer` record + a list; the tables become `List (String × ℕ)` |
| property rewriting | easy | model `Properties = List (String × JSON)`; `objectFromList`/`stringⱼ`/`numberⱼ` exist |
| ASCII-fold / `.upper()` / `.title()` | easy | `Data.Char.toUpper/toLower` + a small fold table (the data has Ø, Í, É, …) |
| round coordinates to 2 dp | easy | digit-list operation on `JSONNumber`; Python's float rounding differs from decimal half-up in rare ties — accept, compare SVGs visually |
| mean-of-vertices centroid | easy | reuse `Scaled` (×10⁴ integers); integer division truncates (≤ 1e-4° from Python) |
| multi-file IO driver (`exe/Earth.agda`) | easy | `IO.Primitive` as in `Main`; stage each file |
| bathymetry simplification | **medium** | Douglas–Peucker is recursive (needs fuel/well-founded recursion, cost O(n²) worst case) — or grid-snap + collinear-drop, which is structural and cheap but cruder; must keep rings closed and non-degenerate |
| memory discipline | **medium** | `tokenize` retains the whole `List Char` (fuel = `length cs`, see `JSONPerfPlan.md` Phase 3); fix or accept ~2 GB peak |
| proofs | optional | e.g. `layer` filters preserve validity (`validateAndExtract`), simplification keeps ring closure; not needed for the map |

Overall: ~2–3 focused days; the mechanical parts are ~1 day, simplification + memory ~1–2 days. Nothing needs
`parsnip` changes except (optionally) the tokenizer fuel.

## Proposed design
- `GeoAgda.Compose` — `record Layer : source path, select : Feature → Bool, rewrite : Feature → Feature`;
  `applyLayer : Layer → FeatureCollection → List Feature`; `composite = concat`.
- `GeoAgda.Compose.Text` — `asciiFold`, `upper`, `title`.
- `GeoAgda.Model.GeoJSON.Simplify` — `roundTo2`, `dedupe`, `simplifyRing` (strategy below).
- `GeoAgda.Compose.Earth` — the recipe: elevation table, peaks, bathymetry levels, nine `Layer`s.
- `exe/Earth.agda` — for each layer: read file → `extractFeatureCollection` → `applyLayer` → *force* the reduced
  list → next; then `renderMapSVG defaultTerrainStyle` → write `earth.svg`. Flag `--geojson out.json` could
  additionally write the composite once encoding (`Feature → JSON`) exists.
- Retire `scripts/build_earth_composite.py` once the SVGs match (see Validation).

## Phases
1. **Recipe without bathymetry** (land, topography, peaks, glaciers, lakes, rivers, borders, labels): `Layer`,
   `Text`, rounding, centroid, `exe/Earth.agda`. All inputs < 11 MB → ~10 s. Validate against the Python fixture
   with its bathymetry layer removed (compare feature counts, properties, and rendered SVG).
2. **Bathymetry**: decide the simplification (below), implement, tune tolerance until feature/vertex counts match
   the fixture (340 / ~130 k) or the map looks equivalent. Parse files one at a time.
3. **Memory/perf pass**: measure with `+RTS -s`; fix tokenizer fuel if the peak matters; decide on `-A` RTS flags.
4. **(Optional)** `Feature → JSON` encoder with the lemma `extractFeatureCollection (encode fc) ≡ just fc`, to
   emit the composite GeoJSON and give the encoder the same round-trip guarantee as the rest of the library.
5. Update the README section; delete the Python script.

## Open decisions (yours)
1. **Bathymetry resolution.** (a) Reproduce the old ~131 k-vertex look with a tuned simplifier (recommended: grid
   snap at ~0.25° + collinear drop first; Douglas–Peucker only if it looks bad); (b) keep committing a
   pre-simplified bathymetry file as an input and do only the merge in Agda (cheapest, but the data stays
   unreproducible); (c) full resolution (~60 MB SVG, slow viewers).
2. **Output**: SVG only, or also the composite GeoJSON (needs the encoder, phase 4)?
3. **Exactness vs the Python output**: byte-identical is not achievable (float rounding, centroid definition);
   is "visually equivalent, same counts and properties" the bar?
4. **Where the recipe lives**: in this repo, or in a separate small package so `GeoAgda` stays generic.
