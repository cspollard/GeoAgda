{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Rendering.SVG.Render where

open import Data.Bool using (true; if_then_else_; _∧_)
open import Data.String as String using (String)
open import Data.List as List using (List; []; _∷_; map; concat; _++_)
open import Data.Product using (_,_)
open import Data.Maybe as Maybe using (Maybe; just; nothing)
open import Function using (case_of_)

open import Data.JSON.AST using (JSON)
open import Data.XML.AST using (XMLDoc)
open import Data.XML.Sanitize using (textElement)
open import Data.SVG
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Coordinates
open import GeoAgda.Rendering.SVG.Style
open import GeoAgda.Rendering.SVG.NaturalEarth

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
  addAttr : String → Maybe String → Attrs → Attrs
  addAttr key nothing  acc = acc
  addAttr key (just v) acc = (key , v) ∷ acc

renderFeatureLabel : Projection → SVGStyle → Feature → List XMLDoc
renderFeatureLabel proj s feat@(feature _ _ props) =
  if (SVGStyle.renderLabels s ∧ (if SVGStyle.topLevelLabelsOnly s then isTopLevelFeature props else true))
  then (case (featureName props) , (featureCentroid feat) of λ where
         (just name , just p) →
           let pt = proj p
           in textElement "text"
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
                name ∷ []
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
                   (just n) → textElement "title" [] n ∷ []
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


-- Top-level renderer using default equirectangular projection
renderMapSVG : SVGStyle → FeatureCollection → XMLDoc
renderMapSVG s fc@(featureCollection _ (just bb)) =
  renderFeatureCollectionWithViewBox equirectangular s (viewBoxComponentsFromBBox bb) fc
renderMapSVG s fc@(featureCollection _ nothing) =
  renderFeatureCollectionWithViewBox equirectangular s defaultWorldViewBoxRec fc
