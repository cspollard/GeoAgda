{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Fixtures where

open import Level using (0ℓ)
open import Data.List using (List; []; _∷_)
open import Data.String as String using (String; toList; fromList)
open import Data.Maybe using (Maybe; just; nothing)
open import Relation.Binary.PropositionalEquality using (_≡_; _≢_; refl)
open import Data.Product using (_×_; _,_; ∃)

open import GeoAgda.Pipeline using (geojsonStringToSVG; geojsonCharsToSVG)
open import Data.XML.AST using (XMLDoc)

------------------------------------------------------------------------
-- Fixture 1: Point FeatureCollection
------------------------------------------------------------------------

pointGeoJSON : String
pointGeoJSON = "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"London\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[-0.12,51.5]}}]}"

pointSVG : Maybe String
pointSVG = geojsonStringToSVG pointGeoJSON

testPointSVGSuccess : ∃ (λ s → pointSVG ≡ just s)
testPointSVGSuccess = _ , refl

------------------------------------------------------------------------
-- Fixture 2: Polygon FeatureCollection with BBox
------------------------------------------------------------------------

polygonGeoJSON : String
polygonGeoJSON = "{\"type\":\"FeatureCollection\",\"bbox\":[-10.0,50.0,2.0,60.0],\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"Box\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[-10.0,50.0],[2.0,50.0],[2.0,60.0],[-10.0,60.0],[-10.0,50.0]]]}}]}"

polygonSVG : Maybe String
polygonSVG = geojsonStringToSVG polygonGeoJSON

testPolygonSVGSuccess : ∃ (λ s → polygonSVG ≡ just s)
testPolygonSVGSuccess = _ , refl

------------------------------------------------------------------------
-- Fixture 3: Natural Earth Country Vector Boundary (Iceland)
------------------------------------------------------------------------

naturalEarthGeoJSON : String
naturalEarthGeoJSON = "{\"type\":\"FeatureCollection\",\"bbox\":[-25.0,63.0,-13.0,67.0],\"features\":[{\"type\":\"Feature\",\"properties\":{\"ADMIN\":\"Iceland\",\"ISO_A3\":\"ISL\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[-14.5,66.4],[-14.7,65.8],[-13.6,65.1],[-14.9,64.3],[-18.2,63.5],[-22.5,63.8],[-24.5,65.5],[-22.3,66.3],[-14.5,66.4]]]}}]}"

naturalEarthSVG : Maybe String
naturalEarthSVG = geojsonStringToSVG naturalEarthGeoJSON

testNaturalEarthSVGSuccess : ∃ (λ s → naturalEarthSVG ≡ just s)
testNaturalEarthSVGSuccess = _ , refl
