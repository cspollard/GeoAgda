{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- The "earth with elevation" map: Natural Earth bathymetry, land,
-- elevation-tinted regions, summits, ice, water, borders and labels.
-- Paths are relative to the `natural-earth-geojson` directory.
--
-- Style: `GeoAgda.Rendering.SVG.NaturalEarth` colours features by `featurecla`
-- and `elevation`, so the properties set here are what the renderer reads.
module GeoAgda.Compose.Earth where

open import Data.Bool using (Bool; true; false; if_then_else_; _∧_; _∨_)
open import Data.List as List using (List; []; _∷_; map) renaming (_++_ to _++ˡ_)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Nat using (ℕ; zero; suc; _≤ᵇ_)
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
open import GeoAgda.Compose.Options
open import GeoAgda.Rendering.SVG.Style using (SVGStyle; defaultTerrainStyle)
open import GeoAgda.Rendering.SVG.Palette using (greenElevationColor)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

simplify : Options → ℕ → Geometry → Maybe Geometry
simplify o r g with Options.precision o
... | zero  = just g
... | suc p = simplifyGeometry (suc p) r g

-- Everything is rounded to `precision`; bathymetry is also thinned to
-- vertices at least `thinning` apart.  Precision 0 keeps geometry untouched.
roundGeom bathyGeom : Options → Geometry → Maybe Geometry
roundGeom o = simplify o 0
bathyGeom o = simplify o (Options.thinning o)

scaleName : Resolution → String
scaleName res10m  = "10m"
scaleName res50m  = "50m"
scaleName res110m = "110m"

-- Path of a Natural Earth file at the chosen scale, e.g. `scaled o "physical" "land"`.
scaled : Options → String → String → String
scaled o theme name = scale ++ "/" ++ theme ++ "/ne_" ++ scale ++ "_" ++ name ++ ".json"
  where scale = scaleName (Options.resolution o)

-- The style the options call for: green shades by elevation, or the
-- hypsometric tints of the areas of interest.
earthStyle : Options → SVGStyle
earthStyle o with Options.land o
... | areas = defaultTerrainStyle
... | _     = record defaultTerrainStyle { elevationPalette = greenElevationColor }

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

  -- Only the areas-of-interest map names its regions.
  regionLabel : Options → String → Geometry → Props
  regionLabel o name g with Options.land o
  ... | areas = ("name" , strP name) ∷ ("LABELRANK" , natP 1) ∷ ("scalerank" , natP 1) ∷ labelProps g
  ... | _     = []

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
bathymetry : Options → String → ℕ → Layer
bathymetry o code depth =
  layer ("10m/physical/ne_10m_bathymetry_" ++ code ++ "_" ++ show depth ++ ".json")
        (λ f → rebuild (bathyGeom o) f (λ _ →
                 ("featurecla" , strP "Bathymetry") ∷ ("depth" , natP depth) ∷ ("scalerank" , natP 10) ∷ []))

-- Without elevation the land is one flat colour.
land : Options → Layer
land o = layer (scaled o "physical" "land")
  (λ f → rebuild (roundGeom o) f (λ _ →
           ("featurecla" , strP "Land") ∷ landElevation (Options.land o) ++ˡ ("scalerank" , natP 10) ∷ []))
  where
    landElevation : LandMode → Props
    landElevation flat = []
    landElevation _    = ("elevation" , natP 50) ∷ []

-- Every landform region of a regions file; the "Iberian Peninsula" name is normalised.
-- Regions are the only elevation data in Natural Earth's vector set: a polygon
-- per named plain, desert, plateau or range, with an elevation from the tables above.
regionsFull : Options → String → Layer
regionsFull o path = layer path convert
  where
    convert : Feature → Maybe Feature
    convert f =
      stringProp (Feature.properties f) "featurecla" >>= λ cla →
      if cla ∈ˢ regionClasses
      then (let raw   = asciiFold (nameOf f)
                uname = upper raw
                name  = if uname == "PENINSULA IBERICA" then "Iberian Peninsula" else title raw
                elev  = Maybe.fromMaybe (defaultElevation cla) (lookupˢ uname regionElevations)
            in rebuild (roundGeom o) f (λ g →
                 ("featurecla" , strP cla) ∷ regionLabel o name g ++ˡ ("elevation" , natP elev) ∷ []))
      else nothing

-- Only the regions of a file that have an entry in the elevation table.
regionsNamed : Options → String → Layer
regionsNamed o path = layer path convert
  where
    convert : Feature → Maybe Feature
    convert f =
      let raw   = asciiFold (nameOf f)
          cla   = Maybe.fromMaybe "Range/mtn" (stringProp (Feature.properties f) "featurecla")
      in lookupˢ (upper raw) regionElevations >>= λ elev →
         rebuild (roundGeom o) f (λ g →
           ("featurecla" , strP cla) ∷ regionLabel o (title raw) g ++ˡ ("elevation" , natP elev) ∷ [])

-- The regions at the chosen scale, then the other scales for names it lacks
-- (the first feature of each name wins).
regions : Options → Group
regions o = group (layers (Options.resolution o))
                (dedupeBy (λ f → Maybe.map upper (stringProp (Feature.properties f) "name")))
  where
    path : String → String
    path r = r ++ "/physical/ne_" ++ r ++ "_geography_regions_polys.json"

    layers : Resolution → List Layer
    layers res10m  = regionsFull o (path "10m") ∷ regionsNamed o (path "50m") ∷ regionsFull o (path "110m") ∷ []
    layers res50m  = regionsFull o (path "50m") ∷ regionsFull o (path "110m") ∷ []
    layers res110m = regionsFull o (path "110m") ∷ regionsNamed o (path "50m") ∷ []

-- Named summits and every 6000 m+ peak.
peaks : Options → Layer
peaks o = layer "10m/physical/ne_10m_geography_regions_elevation_points.json" convert
  where
    convert : Feature → Maybe Feature
    convert f =
      let props = Feature.properties f
          raw   = Maybe.fromMaybe "" (stringProp props "name")
      in natProp props "elevation" >>= λ elev →
         let rank = Maybe.fromMaybe 10 (natProp props "scalerank")
         in if (upper (asciiFold raw) ∈ˢ prominentPeaks) ∨ ((6000 ≤ᵇ elev) ∧ (rank ≤ᵇ 2))
            then rebuild (roundGeom o) f (λ _ →
                   ("featurecla" , strP "spot elevation") ∷ ("name" , strP (asciiFold raw))
                   ∷ ("elevation" , natP elev) ∷ ("scalerank" , natP 1) ∷ [])
            else nothing

-- A layer whose features keep their geometry and get the given class.
plain : Options → String → String → Layer
plain o path cla = layer path
  (λ f → rebuild (roundGeom o) f (λ _ → ("featurecla" , strP cla) ∷ ("scalerank" , natP 10) ∷ []))

glaciers : Options → Layer
glaciers o = plain o (scaled o "physical" "glaciated_areas") "Glaciated areas"

lakes : Options → Layer
lakes o = layer (scaled o "physical" "lakes")
  (λ f → rebuild (roundGeom o) f (λ _ →
           ("featurecla" , strP "Lake") ∷ ("name" , strP (asciiFold (nameOf f))) ∷ ("scalerank" , natP 10) ∷ []))

rivers : Options → Layer
rivers o = plain o (scaled o "physical" "rivers_lake_centerlines") "River"

borders : Options → Layer
borders o = plain o (scaled o "cultural" "admin_0_boundary_lines_land") "Admin-0 boundary lines"

-- A label point for each major country.
countryLabels : Options → Layer
countryLabels o = layer (scaled o "cultural" "admin_0_countries") convert
  where
    convert : Feature → Maybe Feature
    convert f =
      let props = Feature.properties f
          rank  = Maybe.fromMaybe 10 (natProp props "LABELRANK")
          name  = asciiFold (Maybe.fromMaybe "" (firstStringProp ("NAME" ∷ "NAME_EN" ∷ "ADMIN" ∷ []) props))
      in if (rank ≤ᵇ 2) ∧ not-empty name
         then (roundGeom o (Feature.geometry f) >>= λ g →
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

-- Landforms (regions and peaks) are drawn only when elevation or areas
-- of interest are wanted; borders and country names only when asked for.
earthRecipe : Options → Recipe
earthRecipe o =
    simpleGroup (bathymetry o "L" 0)
  ∷ simpleGroup (bathymetry o "K" 200)
  ∷ simpleGroup (bathymetry o "J" 1000)
  ∷ simpleGroup (bathymetry o "I" 2000)
  ∷ simpleGroup (bathymetry o "G" 4000)
  ∷ simpleGroup (bathymetry o "E" 6000)
  ∷ simpleGroup (bathymetry o "A" 10000)
  ∷ simpleGroup (land o)
  ∷ landforms (Options.land o)
  ++ˡ simpleGroup (glaciers o)
  ∷ simpleGroup (lakes o)
  ∷ simpleGroup (rivers o)
  ∷ when (Options.borders o) (simpleGroup (borders o))
  ++ˡ when (Options.countryNames o) (simpleGroup (countryLabels o))
  where
    when : Bool → Group → Recipe
    when true  g = g ∷ []
    when false _ = []

    landforms : LandMode → Recipe
    landforms flat      = []
    landforms elevation = regions o ∷ []
    landforms areas     = regions o ∷ simpleGroup (peaks o) ∷ []
