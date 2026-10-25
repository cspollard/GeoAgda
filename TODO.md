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
