{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone5 where

open import Level using (0ℓ)
open import Data.List.Base using (List; []; _∷_)
open import Data.String.Base as String using (String; _==_)
open import Data.Integer.Base using (+_; -[1+_])
open import Data.Sign.Base using (+; -)
open import Data.Maybe.Base using (just; nothing)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda.Data.JSON.AST using (jsonNum)
open import GeoAgda.Data.XML.AST using (XMLDoc)
open import GeoAgda.Data.XML.Print using (renderXML)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Coordinates
open import GeoAgda.Rendering.SVG.Render

------------------------------------------------------------------------
-- Fixture Data
------------------------------------------------------------------------

-- London: Lon -0.12, Lat 51.5
ptLondon : Position
ptLondon = pos (jsonNum - 0 (1 ∷ 2 ∷ []) (+ 0)) (jsonNum + 51 (5 ∷ []) (+ 0)) nothing

-- Paris: Lon 2.35, Lat 48.85
ptParis : Position
ptParis = pos (jsonNum + 2 (3 ∷ 5 ∷ []) (+ 0)) (jsonNum + 48 (8 ∷ 5 ∷ []) (+ 0)) nothing

testGeomPoint : Geometry
testGeomPoint = pointG ptLondon

testGeomLine : Geometry
testGeomLine = lineStringG (ptLondon ∷ ptParis ∷ [])

testGeomPoly : Geometry
testGeomPoly = polygonG ((ptLondon ∷ ptParis ∷ ptLondon ∷ []) ∷ [])

testFeaturePoint : Feature
testFeaturePoint = feat (just testGeomPoint) [] (just "london-pt")

testFeatureCollection : FeatureCollection
testFeatureCollection = featCol (testFeaturePoint ∷ feat (just testGeomLine) [] nothing ∷ []) nothing

------------------------------------------------------------------------
-- Rendering Tests
------------------------------------------------------------------------

-- Render Point to SVG circle
renderedCircleDoc : XMLDoc
renderedCircleDoc = renderGeometry equirectangular defaultPointStyle testGeomPoint

renderedCircleStr : String
renderedCircleStr = renderXML renderedCircleDoc

-- Verify projected point values at compile time
testProjX : ProjectedPoint.x (equirectangular ptLondon) ≡ "-0.12"
testProjX = refl

testProjY : ProjectedPoint.y (equirectangular ptLondon) ≡ "-51.5"
testProjY = refl

-- Verify line points attribute string
testLinePoints : formatPoints equirectangular (ptLondon ∷ ptParis ∷ []) ≡ "-0.12,-51.5 2.35,-48.85"
testLinePoints = refl

-- Verify polygon path data string
testPolyPath : formatPolygonD equirectangular ((ptLondon ∷ ptParis ∷ ptLondon ∷ []) ∷ []) ≡ "M -0.12,-51.5 L 2.35,-48.85 L -0.12,-51.5 Z"
testPolyPath = refl

-- Render complete FeatureCollection to SVG document
renderedMapDoc : XMLDoc
renderedMapDoc = renderMapSVG defaultPolygonStyle testFeatureCollection

renderedMapStr : String
renderedMapStr = renderXML renderedMapDoc

-- Non-empty output sanity check
_ : String.length renderedMapStr ≢0
_ = λ ()
  where
    open import Data.Nat.Base using (_≢0_)
