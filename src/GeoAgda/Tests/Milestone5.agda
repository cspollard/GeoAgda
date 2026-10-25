{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone5 where

open import Data.List using (List; []; _∷_)
open import Data.Fin.Patterns using (1F; 2F; 3F; 5F; 8F)
open import Data.String as String using (String)
open import Data.String.Properties using (_==_)
open import Data.Integer using (ℤ; +_; -[1+_])
open import Data.Sign using (+; -)
open import Data.Maybe using (just; nothing)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Data.JSON.AST using (jsonNumber)
open import Data.XML.AST using (XMLDoc)
open import Data.XML.Print using (renderXML)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Coordinates
open import GeoAgda.Rendering.SVG.Render
open import GeoAgda.Rendering.SVG.Style

------------------------------------------------------------------------
-- Fixture Data
------------------------------------------------------------------------

-- London: Lon -0.12, Lat 51.5
ptLondon : Position
ptLondon = pos (jsonNumber - 0 (1F ∷ 2F ∷ []) (+_ 0)) (jsonNumber + 51 (5F ∷ []) (+_ 0))

-- Paris: Lon 2.35, Lat 48.85
ptParis : Position
ptParis = pos (jsonNumber + 2 (3F ∷ 5F ∷ []) (+_ 0)) (jsonNumber + 48 (8F ∷ 5F ∷ []) (+_ 0))

testGeomPoint : Geometry
testGeomPoint = pointG ptLondon

testGeomLine : Geometry
testGeomLine = lineStringG (ptLondon ∷ ptParis ∷ [])

testGeomPoly : Geometry
testGeomPoly = polygonG ((ptLondon ∷ ptParis ∷ ptLondon ∷ []) ∷ [])

testFeaturePoint : Feature
testFeaturePoint = feature (just "london-pt") testGeomPoint []

testFeatureCollection : FeatureCollection
testFeatureCollection = featureCollection (testFeaturePoint ∷ feature nothing testGeomLine [] ∷ []) nothing

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
open import Data.Nat using (NonZero)
_ : NonZero (String.length renderedMapStr)
_ = _
