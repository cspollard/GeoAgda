{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Rendering.SVG.Render where

open import Level using (0ℓ)
open import Data.Bool using (Bool; true; false; if_then_else_; _∧_; _∨_; not)
open import Data.Nat using (ℕ; zero; suc; _≤ᵇ_)
open import Data.String as String using (String)
open import Data.String.Properties using (_==_)
open import Data.List as List using (List; []; _∷_; map; concat; _++_)
open import Data.Product using (_×_; _,_)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Function using (_∘_; _$_)

open import GeoAgda.Data.JSON.AST using (JSON; JSONNumber; jsonNumber)
open import GeoAgda.Data.JSON.Schema using (lookupField; asNumber; asString)
open import GeoAgda.Data.XML.AST
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Coordinates

private
  case_of_ : ∀ {A B : Set} → A → (A → B) → B
  case x of f = f x

------------------------------------------------------------------------
-- SVG Styling Configuration
------------------------------------------------------------------------


record SVGStyle : Set where
  constructor svgStyle
  field
    fill               : Maybe String
    stroke             : Maybe String
    strokeWidth        : Maybe String
    opacity            : Maybe String
    pointRadius        : String
    oceanFill          : Maybe String
    useTerrainColors   : Bool
    renderLabels       : Bool
    topLevelLabelsOnly : Bool
    labelFontSize      : String
    labelColor         : String

defaultStyle : SVGStyle
defaultStyle = svgStyle nothing nothing nothing nothing "3" nothing false false false "2.8" "#2b231d"

defaultPointStyle : SVGStyle
defaultPointStyle = svgStyle (just "#e41a1c") (just "#333333") (just "1") nothing "4" nothing false true false "3.0" "#111111"

defaultLineStyle : SVGStyle
defaultLineStyle = svgStyle (just "none") (just "#377eb8") (just "2") nothing "3" nothing false false false "2.8" "#2b231d"

defaultPolygonStyle : SVGStyle
defaultPolygonStyle = svgStyle (just "#4daf4a") (just "#333333") (just "0.05") (just "0.8") "3" nothing false false false "2.8" "#2b231d"

defaultTerrainStyle : SVGStyle
defaultTerrainStyle = svgStyle (just "#a8cca0") (just "#7d7565") (just "0.15") (just "0.95") "3" (just "#092244") true true true "1.2" "#222222"

terrainStyle : SVGStyle
terrainStyle = defaultTerrainStyle

styleToAttrs : SVGStyle → Attributes
styleToAttrs s =
  addAttr "fill" (SVGStyle.fill s)
    (addAttr "stroke" (SVGStyle.stroke s)
      (addAttr "stroke-width" (SVGStyle.strokeWidth s)
        (addAttr "opacity" (SVGStyle.opacity s) [])))
  where
    addAttr : String → Maybe String → Attributes → Attributes
    addAttr key nothing  acc = acc
    addAttr key (just v) acc = (key , v) ∷ acc


------------------------------------------------------------------------
-- Terrain Cartographic Palettes & Property Resolution
------------------------------------------------------------------------

-- Natural Earth bathymetry palette by depth (meters below sea level)
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

-- Natural Earth physical map earth-tone palette for countries/regions
terrainColorByMapIndex : ℕ → String
terrainColorByMapIndex 1 = "#e3d5b8"  -- warm dune sand / coastal plain
terrainColorByMapIndex 2 = "#c2cca0"  -- soft alluvial meadow / river basin
terrainColorByMapIndex 3 = "#d5cb9d"  -- steppe savanna / plateau tan
terrainColorByMapIndex 4 = "#c9b585"  -- warm earth hills / upland
terrainColorByMapIndex 5 = "#b2be96"  -- coastal sage / river delta
terrainColorByMapIndex 6 = "#c89e6c"  -- terracotta clay / highland plateau
terrainColorByMapIndex 7 = "#ad8964"  -- mountain earth / rocky highland
terrainColorByMapIndex _ = "#cad3ab"  -- default natural earth green

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

defaultTerrainFeatureStyle : SVGStyle → Properties → SVGStyle
defaultTerrainFeatureStyle s props with lookupField "elevation" props >>= asNumber
... | just (jsonNumber _ elev _ _) =
  let c = elevationColor elev
  in record s { fill = just c ; stroke = just c ; strokeWidth = just "0.05" }
... | nothing with lookupField "CONTINENT" props >>= asString
...   | just cont =
      record s { fill = just (terrainColorByContinent cont) ; stroke = just "#7d7565" ; strokeWidth = just "0.08" }
...   | nothing   =
      record s { fill = just "#a8cca0" ; stroke = just "#98bc90" ; strokeWidth = just "0.08" }

private
  _∈?_ : String → List String → Bool
  s ∈? [] = false
  s ∈? (x ∷ xs) = if s == x then true else s ∈? xs

terrainStyleByFeatureClass : SVGStyle → String → Properties → SVGStyle
terrainStyleByFeatureClass s cla props =
  if cla == "Bathymetry"
  then (let depth = case lookupField "depth" props >>= asNumber of λ where
                      (just (jsonNumber _ d _ _)) → d
                      nothing → 0
            c = bathymetryColor depth
        in record s { fill = just c ; stroke = just c ; strokeWidth = just "0.02" ; opacity = just "1.0" })
  else if (cla ∈? ("Glaciated areas" ∷ "Antarctic Ice Shelf" ∷ "glacier" ∷ []))
  then record s { fill = just "#f4f9fa" ; stroke = just "#c8dde6" ; strokeWidth = just "0.05" }
  else if cla == "Antarctic Ice Shelf Edge"
  then record s { fill = just "none" ; stroke = just "#b0cce0" ; strokeWidth = just "0.15" }
  else if (cla ∈? ("Lake" ∷ "Reservoir" ∷ "Pluvial lake" ∷ []))
  then record s { fill = just "#7baecb" ; stroke = just "#568dae" ; strokeWidth = just "0.08" }
  else if cla == "Alkaline Lake"
  then record s { fill = just "#8ebed4" ; stroke = just "#6aa0ba" ; strokeWidth = just "0.08" }
  else if (cla ∈? ("River" ∷ "Lake Centerline" ∷ []))
  then record s { fill = just "none" ; stroke = just "#4a90c4" ; strokeWidth = just "0.15" }
  else if cla == "River (Intermittent)"
  then record s { fill = just "none" ; stroke = just "#6baed6" ; strokeWidth = just "0.12" }
  else if cla == "Reefs"
  then record s { fill = just "none" ; stroke = just "#5fb39c" ; strokeWidth = just "0.1" }
  else if (cla ∈? ("Admin-0 boundary lines" ∷ "International boundary (real)" ∷ []))
  then record s { fill = just "none" ; stroke = just "#777065" ; strokeWidth = just "0.2" }
  else if cla == "CountryLabel"
  then record s { fill = just "none" ; stroke = just "none" ; strokeWidth = just "0" ; pointRadius = "0" }
  else if cla == "Coastline"
  then record s { fill = just "none" ; stroke = just "#7a7266" ; strokeWidth = just "0.1" }
  else if cla == "Minor coastline"
  then record s { fill = just "none" ; stroke = just "#7a7266" ; strokeWidth = just "0.08" }
  else if cla == "spot elevation"
  then (case lookupField "elevation" props >>= asNumber of λ where
          (just (jsonNumber _ elev _ _)) →
            record s { fill = just (elevationColor elev) ; stroke = just "#ffffff" ; strokeWidth = just "0.2" ; pointRadius = "1.5" }
          nothing →
            record s { fill = just "#94562c" ; stroke = just "#ffffff" ; strokeWidth = just "0.2" ; pointRadius = "1.5" })
  else (case lookupField "elevation" props >>= asNumber of λ where
          (just (jsonNumber _ elev _ _)) →
            let c = elevationColor elev
            in record s { fill = just c ; stroke = just c ; strokeWidth = just "0.04" }
          nothing →
            if (cla ∈? ("Land" ∷ "land" ∷ []))
            then record s { fill = just "#a8cca0" ; stroke = just "#98bc90" ; strokeWidth = just "0.08" }
            else if (cla ∈? ("Admin-0 country" ∷ "Admin-0 sovereignty" ∷ "Admin-0 map unit" ∷ "Country" ∷ []))
            then record s { fill = just "#a8cca0" ; stroke = just "#8c827a" ; strokeWidth = just "0.2" }
            else if (cla ∈? ("Range/mtn" ∷ "mountain" ∷ "Gorge" ∷ []))
            then record s { fill = just "#94562c" ; stroke = just "#773c1d" ; strokeWidth = just "0.08" }
            else if cla == "Foothills"
            then record s { fill = just "#b37742" ; stroke = just "#94562c" ; strokeWidth = just "0.06" }
            else if (cla ∈? ("Plateau" ∷ "Highland" ∷ []))
            then record s { fill = just "#cb9c62" ; stroke = just "#b37742" ; strokeWidth = just "0.06" }
            else if (cla ∈? ("Desert" ∷ "Playa" ∷ []))
            then record s { fill = just "#eadcb0" ; stroke = just "#dec28a" ; strokeWidth = just "0.05" }
            else if (cla ∈? ("Plain" ∷ "Lowland" ∷ "Valley" ∷ []))
            then record s { fill = just "#dae3a8" ; stroke = just "#bed89f" ; strokeWidth = just "0.05" }
            else if cla == "Basin"
            then record s { fill = just "#bed89f" ; stroke = just "#a8cca0" ; strokeWidth = just "0.05" }
            else if cla == "Tundra"
            then record s { fill = just "#b0c0a0" ; stroke = just "#8fa080" ; strokeWidth = just "0.05" }
            else defaultTerrainFeatureStyle s props)

featureTerrainStyle : SVGStyle → Properties → SVGStyle
featureTerrainStyle s props with lookupField "featurecla" props >>= asString
... | just cla = terrainStyleByFeatureClass s cla props
... | nothing  with lookupField "FEATURECLA" props >>= asString
...   | just cla = terrainStyleByFeatureClass s cla props
...   | nothing  = defaultTerrainFeatureStyle s props

featureTerrainColor : Properties → String
featureTerrainColor props =
  case SVGStyle.fill (featureTerrainStyle defaultTerrainStyle props) of λ where
    (just c) → c
    nothing  → "#cad3ab"

featureClassName : Properties → String
featureClassName props with lookupField "featurecla" props >>= asString
... | just cla = cla
... | nothing  with lookupField "FEATURECLA" props >>= asString
...   | just cla = cla
...   | nothing  = "land-terrain"

featureName : Properties → Maybe String
featureName props with lookupField "NAME" props >>= asString
... | just name = just name
... | nothing   with lookupField "name" props >>= asString
...   | just n = just n
...   | nothing with lookupField "ADMIN" props >>= asString
...     | just admin = just admin
...     | nothing with lookupField "admin" props >>= asString
...       | just a = just a
...       | nothing with lookupField "NAME_EN" props >>= asString
...         | just ne = just ne
...         | nothing with lookupField "name_en" props >>= asString
...           | just ne2 = just ne2
...           | nothing with lookupField "NAME_LONG" props >>= asString
...             | just nl = just nl
...             | nothing with lookupField "sr_subunit" props >>= asString
...               | just su = just su
...               | nothing with lookupField "REGION" props >>= asString
...                 | just r = just r
...                 | nothing = nothing

featureId : Feature → Maybe String
featureId (feature (just fid) _ _) = just fid
featureId (feature nothing _ props) with lookupField "ISO_A3" props >>= asString
... | just iso = just iso
... | nothing  with lookupField "ADM0_A3" props >>= asString
...   | just adm = just adm
...   | nothing  = featureName props

isTopLevelFeature : Properties → Bool
isTopLevelFeature props =
  case lookupField "featurecla" props >>= asString of λ where
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


------------------------------------------------------------------------
-- Geometry Catamorphisms to XML / SVG Free Monad
------------------------------------------------------------------------

mutual
  renderGeometry : Projection → SVGStyle → Geometry → XMLDoc
  renderGeometry proj s (pointG p) =
    let pt = proj p
    in circle (ProjectedPoint.x pt) (ProjectedPoint.y pt) (SVGStyle.pointRadius s) (styleToAttrs s)

  renderGeometry proj s (multiPointG ps) =
    g [] (map (λ p → renderGeometry proj s (pointG p)) ps)

  renderGeometry proj s (lineStringG ps) =
    polyline (formatPoints proj ps) (styleToAttrs s)

  renderGeometry proj s (multiLineStringG pss) =
    g [] (map (λ ps → renderGeometry proj s (lineStringG ps)) pss)

  renderGeometry proj s (polygonG rings) =
    path (formatPolygonD proj rings) (("fill-rule" , "evenodd") ∷ styleToAttrs s)

  renderGeometry proj s (multiPolygonG polys) =
    path (formatMultiPolygonD proj polys) (("fill-rule" , "evenodd") ∷ styleToAttrs s)

  renderGeometry proj s (geometryCollectionG geoms) =
    g [] (renderGeometryList proj s geoms)

  renderGeometryList : Projection → SVGStyle → List Geometry → List XMLDoc
  renderGeometryList proj s []             = []
  renderGeometryList proj s (geom ∷ geoms) =
    renderGeometry proj s geom ∷ renderGeometryList proj s geoms

------------------------------------------------------------------------
-- Feature & FeatureCollection Rendering
------------------------------------------------------------------------

private
  addAttr : String → Maybe String → Attributes → Attributes
  addAttr key nothing  acc = acc
  addAttr key (just v) acc = (key , v) ∷ acc

renderFeatureLabel : Projection → SVGStyle → Feature → List XMLDoc
renderFeatureLabel proj s feat@(feature _ _ props) =
  if (SVGStyle.renderLabels s ∧ (if SVGStyle.topLevelLabelsOnly s then isTopLevelFeature props else true))
  then (case (featureName props) , (featureCentroid feat) of λ where
         (just name , just p) →
           let pt = proj p
           in elementList "text"
                (("x" , ProjectedPoint.x pt) ∷
                 ("y" , ProjectedPoint.y pt) ∷
                 ("text-anchor" , "middle") ∷
                 ("dominant-baseline" , "central") ∷
                 ("font-size" , SVGStyle.labelFontSize s) ∷
                 ("font-family" , "system-ui, -apple-system, sans-serif") ∷
                 ("font-weight" , "bold") ∷
                 ("fill" , SVGStyle.labelColor s) ∷
                 ("stroke" , "#f7f5f0") ∷
                 ("stroke-width" , "0.25") ∷
                 ("paint-order" , "stroke fill") ∷
                 ("class" , "map-label") ∷ [])
                (text name ∷ []) ∷ []
         _ → [])
  else []

renderFeature : Projection → SVGStyle → Feature → XMLDoc
renderFeature proj s feat@(feature _ geom props) =
  let st = if SVGStyle.useTerrainColors s
           then featureTerrainStyle s props
           else s
      geomDoc  = renderGeometry proj st geom
      fid      = featureId feat
      attrs    = addAttr "id" fid (("class" , featureClassName props) ∷ [])
      titleDoc = case featureName props of λ where
                   (just n) → elementList "title" [] (text n ∷ []) ∷ []
                   nothing  → []
  in g attrs (titleDoc ++ (geomDoc ∷ []))

renderFeatureCollectionWithViewBox : Projection → SVGStyle → ViewBox → FeatureCollection → XMLDoc
renderFeatureCollectionWithViewBox proj s vb@(viewBox minX minY w h) (featureCollection features _) =
  let oceanDoc  = case (SVGStyle.oceanFill s) of λ where
                    (just c) → rect minX minY w h (("fill" , c) ∷ ("class" , "ocean-backdrop") ∷ []) ∷ []
                    nothing  → []
      featDocs  = map (renderFeature proj s) features
      labels    = concat (map (renderFeatureLabel proj s) features)
      labelsDoc = case labels of λ where
                    [] → []
                    _  → g (("id" , "top-level-labels") ∷ ("class" , "map-labels-layer") ∷ []) labels ∷ []
  in svg
       (("viewBox" , viewBoxToString vb) ∷ ("width" , "800") ∷ ("height" , "400") ∷ [])
       (oceanDoc ++ featDocs ++ labelsDoc)


renderFeatureCollection : Projection → SVGStyle → String → FeatureCollection → XMLDoc
renderFeatureCollection proj s vBox (featureCollection features _) =
  svg
    (("viewBox" , vBox) ∷ ("width" , "800") ∷ ("height" , "400") ∷ [])
    (map (renderFeature proj s) features)

-- Top-level renderer using default equirectangular projection
renderMapSVG : SVGStyle → FeatureCollection → XMLDoc
renderMapSVG s fc@(featureCollection _ (just bb)) =
  renderFeatureCollectionWithViewBox equirectangular s (viewBoxComponentsFromBBox bb) fc
renderMapSVG s fc@(featureCollection _ nothing) =
  renderFeatureCollectionWithViewBox equirectangular s defaultWorldViewBoxRec fc

renderTerrainMapSVG : FeatureCollection → XMLDoc
renderTerrainMapSVG = renderMapSVG defaultTerrainStyle
