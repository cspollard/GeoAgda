{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- The "earth with elevation" map: Natural Earth bathymetry, land,
-- elevation-tinted regions, summits, ice, water, borders and labels.
-- Paths are relative to the `natural-earth-geojson` directory.
--
-- Style: `GeoAgda.Rendering.SVG.NaturalEarth` colours features by `featurecla`
-- and `elevation`, so the properties set here are what the renderer reads.
module GeoAgda.Compose.Earth where

open import Data.Bool using (Bool; true; false; if_then_else_; _∧_; _∨_)
open import Data.List as List using (List; []; _∷_; map)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Nat using (ℕ; _≤ᵇ_)
open import Data.Nat.Show using (show)
open import Data.Product using (_×_; _,_)
open import Data.String as String using (String; _++_)
open import Data.String.Properties using (_==_)

open import Data.JSON.AST using (JSON; numberⱼ)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Simplify using (simplifyGeometry)
open import GeoAgda.Rendering.SVG.NaturalEarth using (stringProp; natProp; firstStringProp)
open import GeoAgda.Compose
open import GeoAgda.Compose.Text

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

-- 0.01° rounding for everything; bathymetry is also thinned to vertices ≥ 0.3° apart.
roundGeom bathyGeom : Geometry → Maybe Geometry
roundGeom = simplifyGeometry 100 0
bathyGeom = simplifyGeometry 100 3000

private
  Props : Set
  Props = List (String × JSON)

  _∈ˢ_ : String → List String → Bool
  s ∈ˢ []       = false
  s ∈ˢ (x ∷ xs) = if s == x then true else s ∈ˢ xs

  lookupˢ : String → List (String × ℕ) → Maybe ℕ
  lookupˢ k []            = nothing
  lookupˢ k ((k′ , v) ∷ t) = if k == k′ then just v else lookupˢ k t

  -- Rebuild a feature from its (simplified) geometry and new properties.
  rebuild : (Geometry → Maybe Geometry) → Feature → (Geometry → Props) → Maybe Feature
  rebuild simp f props = Maybe.map (λ g → feature nothing g (props g)) (simp (Feature.geometry f))

  nameOf : Feature → String
  nameOf f = Maybe.fromMaybe "" (stringProp (Feature.properties f) "name")

  -- label anchor as LABELX / LABELY properties (absent when there is none)
  labelProps : Geometry → Props
  labelProps g with labelPoint g
  ... | nothing = []
  ... | just (pos x y) = ("LABELX" , numberⱼ x) ∷ ("LABELY" , numberⱼ y) ∷ []

------------------------------------------------------------------------
-- Elevation tables (metres)
------------------------------------------------------------------------

-- Keys are upper-case ASCII names.
regionElevations : List (String × ℕ)
regionElevations =
    ("AMAZON BASIN" , 80) ∷ ("CONGO BASIN" , 350) ∷ ("NORTH CHINA PLAIN" , 50)
  ∷ ("NORTHERN EUROPEAN PLAIN" , 120) ∷ ("KAZAKH STEPPE" , 350) ∷ ("GREAT PLAINS" , 700)
  ∷ ("CANADIAN SHIELD" , 400) ∷ ("GREAT VICTORIA DESERT" , 250) ∷ ("SAHARA" , 450)
  ∷ ("ARABIAN DESERT" , 600) ∷ ("KALAHARI DESERT" , 950) ∷ ("GOBI DESERT" , 1200)
  ∷ ("WESTERN PLATEAU" , 500) ∷ ("DECCAN PLATEAU" , 600) ∷ ("PENINSULA IBERICA" , 650)
  ∷ ("IBERIAN PENINSULA" , 650) ∷ ("GUIANA SHIELD" , 900) ∷ ("BRAZILIAN HIGHLANDS" , 1000)
  ∷ ("CENTRAL SIBERIAN PLATEAU" , 700) ∷ ("COLORADO PLATEAU" , 1900) ∷ ("POLAR PLATEAU" , 2800)
  ∷ ("ALTIPLANO" , 3800) ∷ ("PLATEAU OF TIBET" , 4800) ∷ ("URAL MOUNTAINS" , 1200)
  ∷ ("APPALACHIAN MTS." , 1300) ∷ ("APPALACHIAN MOUNTAINS" , 1300) ∷ ("GREAT DIVIDING RANGE" , 1600)
  ∷ ("KJOLEN MOUNTAINS" , 1600) ∷ ("CARPATHIAN MOUNTAINS" , 1800) ∷ ("ATLAS MOUNTAINS" , 2500)
  ∷ ("PYRENEES" , 2600) ∷ ("ETHIOPIAN HIGHLANDS" , 2600) ∷ ("ZAGROS MOUNTAINS" , 2600)
  ∷ ("ALTAY MOUNTAINS" , 2800) ∷ ("TRANSANTARCTIC MOUNTAINS" , 2800) ∷ ("CASCADE RANGE" , 2800)
  ∷ ("SIERRA NEVADA" , 3000) ∷ ("ALPS" , 3400) ∷ ("ROCKY MOUNTAINS" , 3400)
  ∷ ("CAUCASUS MTS." , 3800) ∷ ("ALASKA RANGE" , 4000) ∷ ("TIAN SHAN" , 4200)
  ∷ ("ANDES" , 4500) ∷ ("HINDU KUSH" , 4800) ∷ ("KUNLUN MOUNTAINS" , 5000)
  ∷ ("KARAKORAM RA." , 6000) ∷ ("HIMALAYAS" , 6500) ∷ []

-- Used for regions that are not in the table.
defaultElevation : String → ℕ
defaultElevation cla =
  if cla ∈ˢ ("Basin" ∷ "Delta" ∷ "Lowland" ∷ []) then 100 else
  if cla ∈ˢ ("Plain" ∷ "Valley" ∷ [])            then 350 else
  if cla == "Tundra"                              then 400 else
  if cla ∈ˢ ("Desert" ∷ "Playa" ∷ [])            then 600 else
  if cla ∈ˢ ("Plateau" ∷ "Highland" ∷ [])        then 1200 else
  if cla == "Foothills"                           then 1500 else
  if cla ∈ˢ ("Range/mtn" ∷ "mountain" ∷ [])      then 2800 else
  100

regionClasses : List String
regionClasses = "Range/mtn" ∷ "Plateau" ∷ "Desert" ∷ "Basin" ∷ "Plain" ∷ "Tundra" ∷ []

prominentPeaks : List String
prominentPeaks =
  "MT. EVEREST" ∷ "K2" ∷ "CERRO ACONCAGUA" ∷ "DENALI" ∷ "MT. KILIMANJARO" ∷ "GORA ELBRUS"
  ∷ "CHIMBORAZO" ∷ "MONT BLANC" ∷ "MT. FUJI" ∷ "MT. COOK" ∷ []

------------------------------------------------------------------------
-- Layers
------------------------------------------------------------------------

-- Depth contours, shallowest first, thinned.
bathymetry : String → ℕ → Layer
bathymetry code depth =
  layer ("10m/physical/ne_10m_bathymetry_" ++ code ++ "_" ++ show depth ++ ".json")
        (λ f → rebuild bathyGeom f (λ _ →
                 ("featurecla" , strP "Bathymetry") ∷ ("depth" , natP depth) ∷ ("scalerank" , natP 10) ∷ []))

land : Layer
land = layer "110m/physical/ne_110m_land.json"
  (λ f → rebuild roundGeom f (λ _ →
           ("featurecla" , strP "Land") ∷ ("elevation" , natP 50) ∷ ("scalerank" , natP 10) ∷ []))

-- Regions from the 110m set; the "Iberian Peninsula" name is normalised.
regions110 : Layer
regions110 = layer "110m/physical/ne_110m_geography_regions_polys.json" convert
  where
    convert : Feature → Maybe Feature
    convert f =
      stringProp (Feature.properties f) "featurecla" >>= λ cla →
      if cla ∈ˢ regionClasses
      then (let raw   = asciiFold (nameOf f)
                uname = upper raw
                name  = if uname == "PENINSULA IBERICA" then "Iberian Peninsula" else title raw
                elev  = Maybe.fromMaybe (defaultElevation cla) (lookupˢ uname regionElevations)
            in rebuild roundGeom f (λ g →
                 ("featurecla" , strP cla) ∷ ("name" , strP name) ∷ ("elevation" , natP elev)
                 ∷ ("LABELRANK" , natP 1) ∷ ("scalerank" , natP 1) ∷ labelProps g))
      else nothing

-- Named ranges and plateaus from the 50m set that the 110m set lacks.
regions50 : Layer
regions50 = layer "50m/physical/ne_50m_geography_regions_polys.json" convert
  where
    convert : Feature → Maybe Feature
    convert f =
      let raw   = asciiFold (nameOf f)
          cla   = Maybe.fromMaybe "Range/mtn" (stringProp (Feature.properties f) "featurecla")
      in lookupˢ (upper raw) regionElevations >>= λ elev →
         rebuild roundGeom f (λ g →
           ("featurecla" , strP cla) ∷ ("name" , strP (title raw)) ∷ ("elevation" , natP elev)
           ∷ ("LABELRANK" , natP 1) ∷ ("scalerank" , natP 1) ∷ labelProps g)

-- The 50m regions only fill in names the 110m set does not have.
regions : Group
regions = group (regions110 ∷ regions50 ∷ [])
                (dedupeBy (λ f → Maybe.map upper (stringProp (Feature.properties f) "name")))

-- Named summits and every 6000 m+ peak.
peaks : Layer
peaks = layer "10m/physical/ne_10m_geography_regions_elevation_points.json" convert
  where
    convert : Feature → Maybe Feature
    convert f =
      let props = Feature.properties f
          raw   = Maybe.fromMaybe "" (stringProp props "name")
      in natProp props "elevation" >>= λ elev →
         let rank = Maybe.fromMaybe 10 (natProp props "scalerank")
         in if (upper (asciiFold raw) ∈ˢ prominentPeaks) ∨ ((6000 ≤ᵇ elev) ∧ (rank ≤ᵇ 2))
            then rebuild roundGeom f (λ _ →
                   ("featurecla" , strP "spot elevation") ∷ ("name" , strP (asciiFold raw))
                   ∷ ("elevation" , natP elev) ∷ ("scalerank" , natP 1) ∷ [])
            else nothing

-- A layer whose features keep their geometry and get the given class.
plain : String → String → Layer
plain path cla = layer path
  (λ f → rebuild roundGeom f (λ _ → ("featurecla" , strP cla) ∷ ("scalerank" , natP 10) ∷ []))

glaciers : Layer
glaciers = plain "110m/physical/ne_110m_glaciated_areas.json" "Glaciated areas"

lakes : Layer
lakes = layer "110m/physical/ne_110m_lakes.json"
  (λ f → rebuild roundGeom f (λ _ →
           ("featurecla" , strP "Lake") ∷ ("name" , strP (asciiFold (nameOf f))) ∷ ("scalerank" , natP 10) ∷ []))

rivers : Layer
rivers = plain "110m/physical/ne_110m_rivers_lake_centerlines.json" "River"

borders : Layer
borders = plain "110m/cultural/ne_110m_admin_0_boundary_lines_land.json" "Admin-0 boundary lines"

-- A label point for each major country.
countryLabels : Layer
countryLabels = layer "110m/cultural/ne_110m_admin_0_countries.json" convert
  where
    convert : Feature → Maybe Feature
    convert f =
      let props = Feature.properties f
          rank  = Maybe.fromMaybe 10 (natProp props "LABELRANK")
          name  = asciiFold (Maybe.fromMaybe "" (firstStringProp ("NAME" ∷ "NAME_EN" ∷ "ADMIN" ∷ []) props))
      in if (rank ≤ᵇ 2) ∧ not-empty name
         then (roundGeom (Feature.geometry f) >>= λ g →
               labelPoint g >>= λ c →
               just (feature nothing (pointG c)
                       (("featurecla" , strP "CountryLabel") ∷ ("NAME" , strP name) ∷ ("LABELRANK" , natP rank)
                        ∷ ("scalerank" , natP 1) ∷ labelProps g)))
         else nothing
      where not-empty : String → Bool
            not-empty s = if s == "" then false else true

------------------------------------------------------------------------
-- The recipe, bottom layer first
------------------------------------------------------------------------

earthRecipe : Recipe
earthRecipe =
    simpleGroup (bathymetry "L" 0)
  ∷ simpleGroup (bathymetry "K" 200)
  ∷ simpleGroup (bathymetry "J" 1000)
  ∷ simpleGroup (bathymetry "I" 2000)
  ∷ simpleGroup (bathymetry "G" 4000)
  ∷ simpleGroup (bathymetry "E" 6000)
  ∷ simpleGroup (bathymetry "A" 10000)
  ∷ simpleGroup land
  ∷ regions
  ∷ simpleGroup peaks
  ∷ simpleGroup glaciers
  ∷ simpleGroup lakes
  ∷ simpleGroup rivers
  ∷ simpleGroup borders
  ∷ simpleGroup countryLabels
  ∷ []
