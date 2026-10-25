# Plan: faster SVG generation

Status: **Phases 1–2 done (2026-10-25).** Phase 3 (further tuning) optional.

## Problem
`bin/Main data/fixtures/ne_110m_admin_0_countries.json` (725 KB, 177 features) took **93 s**. The 569-byte sample
took 0.24 s. Cost was linear in the number of vertices but with a huge constant (~24 ms per vertex).

## Phase 1 — measure, don't guess (done)
`exe/Profile.agda` (`Profile <stage> <file>`) runs the pipeline up to a stage and prints a number that forces the
work: `read`, `tokenize`, `parse`, `json` (parse + print), `extract`, `svg`, plus micro stages (`path`, `centroid`,
`style`, `svgfeat`, `svgplain`, `xmlbig`, `numbers`). Findings on the countries file:

| stage | time |
|---|---|
| read / tokenize / parse / extract | 0.6 s / 0.67 s / 0.67 s / 0.67 s (of which ~0.55 s is process start-up) |
| path strings, XML print, sanitising (`xmlbig`: 100 000-char attribute) | ≤ 0.06 s |
| `svg` (terrain style) | **93 s** |
| `svg` with `defaultPolygonStyle` | 0.00 s |

So the JSON/XML libraries are not the problem. The difference between the two styles is the **label layer**
(`renderLabels`), whose `featureCentroid` computes a bounding box of each feature's first ring.

Root cause: `positionsBBoxScaled` used `Data.Integer._⊓_` / `_⊔_`, which bottom out in `Data.Nat._⊓_` / `_⊔_`,
defined by recursion on the *magnitude* (`suc m ⊓ suc n = suc (m ⊓ n)`). Coordinates are scaled by 10⁴, so a
longitude of 180.0 costs ~10⁶ steps per min/max, four times per vertex.

## Phase 2 — fix (done)
- In `GeoAgda.Rendering.SVG.Coordinates`, `minℤ`/`maxℤ` use a sign-aware `_<ᶻ_` built on the primitive
  `Data.Nat._<ᵇ_` (constant time, GHC `Integer` comparison).
- Result: **93 s → 0.4 s**, byte-identical SVG (checked with `cmp`) for the countries and sample fixtures; the
  2.4 MB `earth_physical_topography.geojson` renders in 2.4 s.
- Ergonomics are unchanged: no API change, the library (`parsnip`) was not touched.
- `Makefile`: `SRC_FILES` now includes `parsnip/src`, so edits to the library trigger a rebuild of `bin/Main`.

## Phase 3 — remaining hot spots (optional)
- Audit other stdlib functions that recurse on magnitude (`_∸_`, `_⊓_`, `_⊔_`, `Data.Digit.toDigits`,
  `Data.Nat.DivMod` with well-founded recursion) — see `plans/JSONPerfPlan.md` for `printNat`.
- Start-up cost of ~0.5 s per run (probably CAF initialisation of the big module graph) — investigate with
  `+RTS -s` if it matters.
