# TODO

- [x] **Vectorized elevation data for the earth map.** Natural Earth's GeoJSON set has no elevation
  raster or contours: land shading comes from ~400 named landform regions with table elevations
  (`GeoAgda.Compose.Earth`). Get a real elevation source, vectorize it into elevation-band polygons
  (GeoJSON), and add it as a layer for `--land=elevation`.
  - pick an open DEM (e.g. NOAA ETOPO 2022), script the download and vectorization (`scripts/`);
  - bands follow the green palette thresholds in `GeoAgda.Rendering.SVG.Palette`;
  - clip to / draw above the 10m land; keep the output size manageable (simplify in the script and
    via `--precision` / `--thin`);
  - wire an Agda layer + option, document in the README.

- [ ] **Lower the memory of `bin/Earth`** (peak 5.6 GB with the ETOPO bands at `--precision=0`; wall time is
  dominated by paging, 316 s CPU vs 1394 s wall). The renderer holds every feature of every layer until the
  single `writeFile`. Keep full precision (the map is printed wall-sized); fix the retention, not the detail.
  1. *Measure first*: `+RTS -s -hT` on a run; bytes per vertex and what is retained (parsed `JSON`, the
     `List Char` of the file text, or the converted `Feature`s).
  2. *Stream per group*: the recipe is already one group per band. Render each group to an SVG fragment and
     `appendFile` it (`IO.Primitive.Finite.appendFile`), with the `<svg>` header written first from the fixed
     world viewBox. Peak becomes the largest group (one band), not the sum. No new abstractions.
  3. *`PathC` container* (`Data.Container`), see the design notes in `plans/PathPlan.md`: a ring is
     `PathC ⋆ ⊥` with `PathC = PathShape ▷ …` (moveTo / lineTo / close, scaled-integer coordinates
     instead of `JSONNumber` digit lists). JSON → Path goes through the GeoJSON schema decode, then a
     handler `GeoC ⇒ PathC ⋆`; Path → SVG is the algebra `PathC ⟦ String ⟧ → String` that prints the
     `d` attribute, wrapped into an `XMLC` node by the style rules. Only if 2 is not enough.
- [ ] **Projections**: see `plans/ProjectionPlan.md` (Equal Earth first, interrupted forms later).
