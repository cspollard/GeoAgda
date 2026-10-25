{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Natural Earth specific conventions: property names, feature classes and
-- the cartographic palette used to style them.
module GeoAgda.Rendering.SVG.NaturalEarth where

open import Data.Bool using (Bool; true; false; if_then_else_)
open import Data.Nat using (ℕ; _≤ᵇ_)
open import Data.String using (String)
open import Data.String.Properties using (_==_)
open import Data.List as List using (List; []; _∷_; map; foldr)
open import Data.Bool.ListAction using (any)
open import Data.Product using (_×_; _,_)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_; _<∣>_)
open import Function using (case_of_)

open import Data.JSON.AST using (jsonNumber)
open import Data.JSON.Schema using (lookupField; asNumber; asString)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Style

------------------------------------------------------------------------
-- Property lookup
------------------------------------------------------------------------

stringProp : Properties → String → Maybe String
stringProp props key = lookupField key props >>= asString

firstJust : ∀ {A : Set} → List (Maybe A) → Maybe A
firstJust = foldr _<∣>_ nothing

-- The first of the given property names that holds a string.
firstStringProp : List String → Properties → Maybe String
firstStringProp keys props = firstJust (map (stringProp props) keys)

featureClass : Properties → Maybe String
featureClass = firstStringProp ("featurecla" ∷ "FEATURECLA" ∷ [])

featureClassName : Properties → String
featureClassName props = Maybe.fromMaybe "land-terrain" (featureClass props)

featureName : Properties → Maybe String
featureName = firstStringProp
  ( "NAME" ∷ "name" ∷ "ADMIN" ∷ "admin" ∷ "NAME_EN" ∷ "name_en"
  ∷ "NAME_LONG" ∷ "sr_subunit" ∷ "REGION" ∷ [])

featureId : Feature → Maybe String
featureId (feature (just fid) _ _) = just fid
featureId (feature nothing _ props) =
  firstStringProp ("ISO_A3" ∷ "ADM0_A3" ∷ []) props <∣> featureName props

------------------------------------------------------------------------
-- Palettes
------------------------------------------------------------------------

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

-- Natural Earth elevation palette (meters above sea level)
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

------------------------------------------------------------------------
-- Numeric property lookup
------------------------------------------------------------------------

natProp : Properties → String → Maybe ℕ
natProp props key =
  Maybe.map (λ { (jsonNumber _ n _ _) → n }) (lookupField key props >>= asNumber)

elevationOf : Properties → Maybe ℕ
elevationOf props = natProp props "elevation"

------------------------------------------------------------------------
-- Fallback styling (no feature class)
------------------------------------------------------------------------

defaultTerrainFeatureStyle : SVGStyle → Properties → SVGStyle
defaultTerrainFeatureStyle s props with elevationOf props
... | just e  = solid (elevationColor e) "0.05" s
... | nothing with stringProp props "CONTINENT"
...   | just cont = paint (terrainColorByContinent cont) "#7d7565" "0.08" s
...   | nothing   = paint "#a8cca0" "#98bc90" "0.08" s

------------------------------------------------------------------------
-- Feature-class styling rules
------------------------------------------------------------------------

-- A rule may inspect the feature's properties.
Rule : Set
Rule = Properties → SVGStyle → SVGStyle

-- A table maps groups of feature-class names to the rule for the group.
Table : Set
Table = List (List String × Rule)

static : (SVGStyle → SVGStyle) → Rule
static f _ = f

lookupRule : String → Table → Maybe Rule
lookupRule cla []                  = nothing
lookupRule cla ((names , r) ∷ rs)  =
  if any (cla ==_) names then just r else lookupRule cla rs

-- Rules that apply whatever the feature carries.
classRules : Table
classRules =
    ("Bathymetry" ∷ [] ,
       λ props s → let c = bathymetryColor (Maybe.fromMaybe 0 (natProp props "depth"))
                   in record (solid c "0.02" s) { opacity = just "1.0" })
  ∷ ("Glaciated areas" ∷ "Antarctic Ice Shelf" ∷ "glacier" ∷ [] , static (paint "#f4f9fa" "#c8dde6" "0.05"))
  ∷ ("Antarctic Ice Shelf Edge" ∷ [] , static (outline "#b0cce0" "0.15"))
  ∷ ("Lake" ∷ "Reservoir" ∷ "Pluvial lake" ∷ [] , static (paint "#7baecb" "#568dae" "0.08"))
  ∷ ("Alkaline Lake" ∷ [] , static (paint "#8ebed4" "#6aa0ba" "0.08"))
  ∷ ("River" ∷ "Lake Centerline" ∷ [] , static (outline "#4a90c4" "0.15"))
  ∷ ("River (Intermittent)" ∷ [] , static (outline "#6baed6" "0.12"))
  ∷ ("Reefs" ∷ [] , static (outline "#5fb39c" "0.1"))
  ∷ ("Admin-0 boundary lines" ∷ "International boundary (real)" ∷ [] , static (outline "#777065" "0.2"))
  ∷ ("CountryLabel" ∷ [] ,
       static (λ s → record (paint "none" "none" "0" s) { pointRadius = "0" }))
  ∷ ("Coastline" ∷ [] , static (outline "#7a7266" "0.1"))
  ∷ ("Minor coastline" ∷ [] , static (outline "#7a7266" "0.08"))
  ∷ ("spot elevation" ∷ [] ,
       λ props s → let c = Maybe.maybe elevationColor "#94562c" (elevationOf props)
                   in record (paint c "#ffffff" "0.2" s) { pointRadius = "1.5" })
  ∷ []

-- Landform rules, used only for features without an elevation.
landformRules : Table
landformRules =
    ("Land" ∷ "land" ∷ [] , static (paint "#a8cca0" "#98bc90" "0.08"))
  ∷ ("Admin-0 country" ∷ "Admin-0 sovereignty" ∷ "Admin-0 map unit" ∷ "Country" ∷ [] , static (paint "#a8cca0" "#8c827a" "0.2"))
  ∷ ("Range/mtn" ∷ "mountain" ∷ "Gorge" ∷ [] , static (paint "#94562c" "#773c1d" "0.08"))
  ∷ ("Foothills" ∷ [] , static (paint "#b37742" "#94562c" "0.06"))
  ∷ ("Plateau" ∷ "Highland" ∷ [] , static (paint "#cb9c62" "#b37742" "0.06"))
  ∷ ("Desert" ∷ "Playa" ∷ [] , static (paint "#eadcb0" "#dec28a" "0.05"))
  ∷ ("Plain" ∷ "Lowland" ∷ "Valley" ∷ [] , static (paint "#dae3a8" "#bed89f" "0.05"))
  ∷ ("Basin" ∷ [] , static (paint "#bed89f" "#a8cca0" "0.05"))
  ∷ ("Tundra" ∷ [] , static (paint "#b0c0a0" "#8fa080" "0.05"))
  ∷ []

terrainStyleByFeatureClass : SVGStyle → String → Properties → SVGStyle
terrainStyleByFeatureClass s cla props with lookupRule cla classRules
... | just r  = r props s
... | nothing with elevationOf props
...   | just e  = solid (elevationColor e) "0.04" s
...   | nothing with lookupRule cla landformRules
...     | just r  = r props s
...     | nothing = defaultTerrainFeatureStyle s props

featureTerrainStyle : SVGStyle → Properties → SVGStyle
featureTerrainStyle s props with featureClass props
... | just cla = terrainStyleByFeatureClass s cla props
... | nothing  = defaultTerrainFeatureStyle s props

------------------------------------------------------------------------
-- Label eligibility
------------------------------------------------------------------------

private
  _∈?_ : String → List String → Bool
  s ∈? names = any (s ==_) names

isTopLevelFeature : Properties → Bool
isTopLevelFeature props =
  case stringProp props "featurecla" of λ where
    (just cla) →
      if (cla ∈? ("Bathymetry" ∷ "Coastline" ∷ "Minor coastline" ∷ "Reefs" ∷ "River" ∷ "Lake Centerline" ∷ "River (Intermittent)" ∷ "Admin-0 boundary lines" ∷ "Land" ∷ "land" ∷ "Glaciated areas" ∷ []))
      then false
      else checkRanks
    nothing → checkRanks
  where
    checkRanks : Bool
    checkRanks =
      case lookupField "LABELRANK" props >>= asNumber of λ where
        (just (jsonNumber _ rank _ _)) → rank ≤ᵇ 2
        nothing → case lookupField "scalerank" props >>= asNumber of λ where
          (just (jsonNumber _ srank _ _)) → srank ≤ᵇ 1
          nothing → true
