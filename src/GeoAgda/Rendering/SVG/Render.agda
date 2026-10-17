{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Rendering.SVG.Render where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.String.Base as String using (String; _++_)
open import Data.List.Base as List using (List; []; _∷_; map; concat)
open import Data.Product.Base using (_×_; _,_)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Function.Base using (_∘_; _$_)

open import GeoAgda.Data.XML.AST
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Coordinates

------------------------------------------------------------------------
-- SVG Styling Configuration
------------------------------------------------------------------------

record SVGStyle : Set where
  constructor svgStyle
  field
    fill        : Maybe String
    stroke      : Maybe String
    strokeWidth : Maybe String
    opacity     : Maybe String
    pointRadius : String

defaultStyle : SVGStyle
defaultStyle = svgStyle nothing nothing nothing nothing "3"

defaultPointStyle : SVGStyle
defaultPointStyle = svgStyle (just "#e41a1c") (just "#333333") (just "1") nothing "4"

defaultLineStyle : SVGStyle
defaultLineStyle = svgStyle (just "none") (just "#377eb8") (just "2") nothing "3"

defaultPolygonStyle : SVGStyle
defaultPolygonStyle = svgStyle (just "#4daf4a") (just "#333333") (just "1") (just "0.8") "3"

styleToAttrs : SVGStyle → Attributes
styleToAttrs (svgStyle f s sw op _) =
  addAttr "fill" f (addAttr "stroke" s (addAttr "stroke-width" sw (addAttr "opacity" op [])))
  where
    addAttr : String → Maybe String → Attributes → Attributes
    addAttr key nothing  acc = acc
    addAttr key (just v) acc = (key , v) ∷ acc

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
    g [] (map (renderGeometry proj s) geoms)

------------------------------------------------------------------------
-- Feature & FeatureCollection Rendering
------------------------------------------------------------------------

renderFeature : Projection → SVGStyle → Feature → XMLDoc
renderFeature proj s (feat nothing _ _) =
  g [] []
renderFeature proj s (feat (just geom) _ nothing) =
  renderGeometry proj s geom
renderFeature proj s (feat (just geom) _ (just fid)) =
  g (("id" , fid) ∷ []) (renderGeometry proj s geom ∷ [])

renderFeatureCollection : Projection → SVGStyle → String → FeatureCollection → XMLDoc
renderFeatureCollection proj s vBox (featCol features _) =
  svg
    (("viewBox" , vBox) ∷ ("width" , "100%") ∷ ("height" , "100%") ∷ [])
    (map (renderFeature proj s) features)

-- Convenience top-level renderer using default equirectangular projection
renderMapSVG : SVGStyle → FeatureCollection → XMLDoc
renderMapSVG s fc@(featCol _ (just bb)) =
  renderFeatureCollection equirectangular s (viewBoxFromBBox bb) fc
renderMapSVG s fc@(featCol _ nothing) =
  renderFeatureCollection equirectangular s defaultWorldViewBox fc
