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
  2. *`PathC` container* (`Data.Container`), **first**: see `plans/PathPlan.md`. A path is `PathM ⊥` (`PathM A = PathC ⋆ A`) with
     `PathC = PathShape ▷ …` (moveTo / lineTo / close / stop, scaled-integer geographic coordinates instead of
     `JSONNumber` digit lists); the projection is applied when printing. Chosen before streaming because
     streaming precludes operations that need all the data in memory.
  (Status: `Path` is implemented and wired in (`plans/PathPlan.md`, Status/Result). Retained geometry is 8× smaller per
  vertex (930 → 114 B), and two retention leaks are fixed (`rebuild`'s properties thunk; the shape of `loadLayer`, which
  kept every loaded file's source alive until the load ended). Loading the full `--precision=0` map now peaks at about
  1.2 GB. The run then exhausts a 4 GB heap *rendering*: the 194 MB SVG is built as a `List Char` (≈ 41 B per char).
  Output is now written in chunks (`Data.XML.Chunks`, one `appendFile` per feature): the full `--precision=0` map
  completes under a 4 GB heap (`-c`), 102 s, max residency 2.5 GB. Still above the loaded features (1.2 GB): look for
  what rendering holds per feature, and the ~130 MB of JSON numbers kept alive after loading; see `plans/PathPlan.md`.)
  3. *Stream per group*, only if 2 is not enough: render each group to an SVG fragment and `appendFile` it
     (`IO.Primitive.Finite.appendFile`), `<svg>` header first from the fixed world viewBox. Peak becomes the
     largest group, at the cost of whole-dataset operations.
- [ ] **Projections**: see `plans/ProjectionPlan.md` (Equal Earth first, interrupted forms later).
