{-# OPTIONS --safe --cubical-compatible #-}

-- Elevation palettes: metres above sea level -> fill colour.  The renderer
-- takes one as `SVGStyle.elevationPalette`.
module GeoAgda.Rendering.SVG.Palette where

open import Data.Bool using (if_then_else_)
open import Data.Nat using (ℕ; _≤ᵇ_)
open import Data.String using (String)

-- Natural Earth hypsometric tints (meters above sea level)
-- Hypsometric tints: lush coastal green -> spring green -> yellow-green -> savanna buff -> upland tan -> plateau ochre -> sienna -> alpine brown -> snow cap
elevationColor : ℕ → String
elevationColor e =
  if e ≤ᵇ 100  then "#a8cca0" else   -- 0 - 100m: lowlands & coastal plains (lush green)
  if e ≤ᵇ 250  then "#bed89f" else   -- 100 - 250m: lowlands & valleys (soft spring green)
  if e ≤ᵇ 500  then "#dae3a8" else   -- 250 - 500m: plains & rolling lowlands (warm yellow-green)
  if e ≤ᵇ 800  then "#eadcb0" else   -- 500 - 800m: interior plains & steppes (buff savanna tan)
  if e ≤ᵇ 1200 then "#dec28a" else   -- 800 - 1200m: upland plateaus & hills (warm ochre tan)
  if e ≤ᵇ 1800 then "#cb9c62" else   -- 1200 - 1800m: highlands & lower plateaus (rich ochre)
  if e ≤ᵇ 2800 then "#b37742" else   -- 1800 - 2800m: mountains (warm sienna)
  if e ≤ᵇ 4000 then "#94562c" else   -- 2800 - 4000m: high ranges (deep sienna)
  if e ≤ᵇ 5000 then "#773c1d" else   -- 4000 - 5000m: rugged alpine crags (deep mountain brown)
  "#e8eef2"                          -- 5000m+: glaciated summits & snow caps

-- Shades of green only: the higher the land, the darker the green.
greenElevationColor : ℕ → String
greenElevationColor e =
  if e ≤ᵇ 100  then "#cfe8bd" else
  if e ≤ᵇ 250  then "#b9dba2" else
  if e ≤ᵇ 500  then "#9fcc87" else
  if e ≤ᵇ 800  then "#85bb70" else
  if e ≤ᵇ 1200 then "#6aa85b" else
  if e ≤ᵇ 1800 then "#529348" else
  if e ≤ᵇ 2800 then "#3d7c37" else
  if e ≤ᵇ 4000 then "#2c6429" else
  "#1e4d1d"
