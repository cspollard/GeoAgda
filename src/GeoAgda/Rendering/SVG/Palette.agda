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

-- Desaturated and brightened: gentle sage green up to soft, bright off-white.
greenElevationColor : ℕ → String
greenElevationColor e =
  if e ≤ᵇ 100  then "#536352" else
  if e ≤ᵇ 250  then "#677866" else
  if e ≤ᵇ 500  then "#7c8d7b" else
  if e ≤ᵇ 800  then "#93a392" else
  if e ≤ᵇ 1200 then "#abbbaa" else
  if e ≤ᵇ 1800 then "#c3cec2" else
  if e ≤ᵇ 2800 then "#dbe3db" else
  if e ≤ᵇ 4000 then "#ecf0ec" else
  "#fbfcfb"

-- Natural Earth bathymetry palette by depth (meters below sea level)
bathymetryColor : ℕ → String
bathymetryColor d =
  if d ≤ᵇ 0    then "#bfe3eb" else
  if d ≤ᵇ 200  then "#9ecae1" else
  if d ≤ᵇ 1000 then "#6baed6" else
  if d ≤ᵇ 2000 then "#4292c6" else
  if d ≤ᵇ 3000 then "#2171b5" else
  if d ≤ᵇ 4000 then "#08519c" else
  if d ≤ᵇ 5000 then "#084081" else
  if d ≤ᵇ 6000 then "#08306b" else
  if d ≤ᵇ 8000 then "#052052" else
  if d ≤ᵇ 9000 then "#03143c" else
  "#020b24"

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
