{-# OPTIONS --safe --cubical-compatible #-}

-- Colour palettes: bathymetry by depth, land by elevation (hypsometric and
-- green) and by continent.  The renderer takes the elevation palette as
-- `SVGStyle.elevationPalette`.
module GeoAgda.Rendering.SVG.Palette where

open import Data.Bool using (if_then_else_)
open import Data.Nat using (ℕ; _≤ᵇ_)
open import Data.String using (String)
open import Data.String.Properties using (_==_)

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

-- Bright but muted: sage green up to soft, bright off-white.
greenElevationColor : ℕ → String
greenElevationColor e =
  if e ≤ᵇ 100  then "#7a9876" else
  if e ≤ᵇ 250  then "#8aa686" else
  if e ≤ᵇ 500  then "#9bb497" else
  if e ≤ᵇ 800  then "#adc2a9" else
  if e ≤ᵇ 1200 then "#bfd0bb" else
  if e ≤ᵇ 1800 then "#d0ddcc" else
  if e ≤ᵇ 2800 then "#e1eadd" else
  if e ≤ᵇ 4000 then "#eff4ed" else
  "#fbfdfa"

-- Natural Earth bathymetry palette by depth (meters below sea level)
bathymetryColor : ℕ → String
bathymetryColor d =
  if d ≤ᵇ 0    then "#d3e6ea" else
  if d ≤ᵇ 200  then "#bcd6e0" else
  if d ≤ᵇ 1000 then "#a2c1d3" else
  if d ≤ᵇ 2000 then "#89acc6" else
  if d ≤ᵇ 3000 then "#7399b8" else
  if d ≤ᵇ 4000 then "#6289a9" else
  if d ≤ᵇ 5000 then "#547899" else
  if d ≤ᵇ 6000 then "#486889" else
  if d ≤ᵇ 8000 then "#3d5a7a" else
  if d ≤ᵇ 9000 then "#334c69" else
  "#2a4059"

-- Lake depth in metres below the lake's own surface: the neutral lake blue
-- (`#9bbfd0`) deepening to a muted navy.
lakeDepthColor : ℕ → String
lakeDepthColor d =
  if d ≤ᵇ 25   then "#8cb3c7" else
  if d ≤ᵇ 50   then "#7da5bb" else
  if d ≤ᵇ 100  then "#6e97af" else
  if d ≤ᵇ 200  then "#5f89a3" else
  if d ≤ᵇ 400  then "#527b96" else
  if d ≤ᵇ 800  then "#456d89" else
  "#39607c"

terrainColorByContinent : String → String
terrainColorByContinent c =
  if c == "Africa"        then "#d8be91" else
  if c == "Asia"          then "#c6cca2" else
  if c == "Europe"        then "#bdcaa0" else
  if c == "North America" then "#c2bea0" else
  if c == "South America" then "#b5c494" else
  if c == "Oceania"       then "#d9c69f" else
  if c == "Antarctica"    then "#eef5f8" else
  "#cad3ab"
