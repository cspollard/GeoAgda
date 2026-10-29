# Projection plan

Today there is one projection, `equirectangular` (`GeoAgda.Rendering.SVG.Projection`), and
`Projection = Position → ProjectedPoint` is pointwise. It prints the source `JSONNumber`s unchanged,
so no arithmetic is involved. Plate carrée stretches the poles (Antarctica, Greenland, the Arctic
coasts) and makes a wall-sized print look lopsided. Goal: pick a projection with `--projection=`,
including interrupted ones that duplicate some coordinates to avoid polar smearing.

## Candidates

| `--projection=`       | pointwise | polar behaviour                | cost |
|-----------------------|-----------|--------------------------------|------|
| `equirectangular`     | yes       | worst: poles are full width    | exists |
| `equal-earth`         | yes       | poles are lines, 0.6 × equator | closed form, no iteration |
| `mollweide`           | yes       | poles are points               | 5–6 Newton steps per vertex |
| `interrupted-mollweide` | per lobe | poles are points, no shear at the cuts | clipping + lobe table |
| `goode`               | per lobe  | as above, sinusoidal near the equator (least shape distortion) | clipping + two formulas |

Equal Earth (Šavrič, Patterson, Jenny 2018), with A₁=1.340264, A₂=−0.081106, A₃=0.000893, A₄=0.003796:

    sin θ = (√3/2) sin φ
    x = 2√3 λ cos θ / (3 (A₁ + 3A₂θ² + θ⁶(7A₃ + 9A₄θ²)))
    y = θ (A₁ + A₂θ² + θ⁶(A₃ + A₄θ²))

## Steps

1. **Arithmetic.** `Agda.Builtin.Float` (`sin`, `cos`, `asin`, `sqrt`; allowed under `--safe`). Longitude and
   latitude arrive as `JSONNumber`; convert through the scaled integers of `Scaled.agda`. Output: round to a
   fixed number of decimals (`--projection-digits`, default 3 in the map's units) and print through `ℤ`,
   not `primShowFloat` (no exponents, stable text). Tests compare rounded `ℤ`s, not Floats.
2. **Interface.** Keep `Projection` for pointwise use and add

       record MapProjection : Set where
         project : Position → ProjectedPoint
         outline : List Position       -- lon/lat boundary of the map, densified
         lobes   : List Lobe           -- one lobe for pointwise projections
         bounds  : ViewBox             -- of the projected outline

   `renderMapSVG` takes a `MapProjection`; `equirectangular` becomes the one-lobe case, so every existing
   test and output stays as it is.
3. **Backdrop and viewBox.** The ocean is a lon/lat rectangle today. Draw the projected `outline` instead
   (densified so edges curve), and compute the viewBox from `bounds`, not from the data. Optional graticule
   from the same densifier.
4. **Equal Earth** as `--projection=equal-earth`, plus `mollweide` (fixed number of Newton iterations,
   no fuel argument needed since the count is a constant).
5. **Interrupted projections.** A `Lobe` is a lon strip `[λ₀, λ₁]` with a central meridian and a latitude range
   (north/south lobes of Goode differ). A polygon that crosses a cut is clipped into one piece per lobe it
   touches; the piece is projected with that lobe's central meridian. The vertices on the cut are the
   duplicated coordinates.
   - Clipping against a strip is Sutherland–Hodgman against two vertical half-planes, which is exact for
     rings of any shape (it may add edges along the cut, which lie on the lobe boundary and are harmless for fills).
     Intersections computed in scaled `ℤ` with one rounding step.
   - Polylines (rivers, borders) clip into several polylines; point labels go to the lobe that contains them.
   - Where the data is already per band (`bathymetry_*`, `elevation_*`), clipping can also be done
     once in `scripts/build_elevation_bands.py` (shapely), so the Agda run reads less work. Decide after step 4.
   - Standard lobe tables: interrupted Mollweide (land-centred, cuts through Atlantic, Pacific, Indian
     Ocean) and Goode homolosine; keep the tables as data in `GeoAgda.Rendering.SVG.Projection.Lobes`.
6. **Options and docs.** `--projection=`, `--projection-digits=`; README section with a picture of each.
7. **Proofs and tests.** `equirectangular` agrees with the old formatter (refl on the existing tests); Equal
   Earth hits known points (equator/prime meridian = (0,0), (180°,0) = ±2.7 in x for the unit-sphere formula,
   poles at |y| ≈ 1.31); clipping preserves the area of the pieces (test on a rectangle crossing a cut);
   every clipped vertex lies in its lobe.

## Order

Equal Earth first (steps 1–4): it is pointwise, so it needs no clipping and answers most of the
polar-smear complaint. Interrupted forms (step 5) only if Equal Earth is not enough for the print.
Independent of the memory work in `TODO.md`, but both change the render step, so do the streaming-per-group
change first.
