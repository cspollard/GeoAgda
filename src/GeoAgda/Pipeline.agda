{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Pipeline where

open import Level using (0ℓ)
open import Data.Char.Base using (Char)
open import Data.String.Base as String using (String; toList; fromList)
open import Data.List.Base using (List)
open import Data.Maybe.Base using (Maybe; just; nothing; _>>=_)
open import Function.Base using (_∘_; _$_)

open import GeoAgda.Data.JSON.AST using (JSON)
open import GeoAgda.Data.XML.AST using (XMLDoc)
open import GeoAgda.Data.XML.Print using (renderXML)
open import GeoAgda.Parsing.JSON.Parser using (parseJSON)
open import GeoAgda.Model.GeoJSON.Types using (FeatureCollection)
open import GeoAgda.Model.GeoJSON.Extraction using (extractFeatureCollection)
open import GeoAgda.Rendering.SVG.Render using (renderMapSVG; defaultPolygonStyle; defaultTerrainStyle; SVGStyle)

------------------------------------------------------------------------
-- Complete End-to-End Ingestion & Rendering Pipeline
------------------------------------------------------------------------

-- Ingest GeoJSON character stream directly to SVG XML Free Monad
geojsonDocToSVGWithStyle : SVGStyle → List Char → Maybe XMLDoc
geojsonDocToSVGWithStyle style input = do
  jsonVal ← parseJSON input
  fc      ← extractFeatureCollection jsonVal
  just (renderMapSVG style fc)

geojsonDocToSVG : List Char → Maybe XMLDoc
geojsonDocToSVG = geojsonDocToSVGWithStyle defaultTerrainStyle

geojsonDocToPlainSVG : List Char → Maybe XMLDoc
geojsonDocToPlainSVG = geojsonDocToSVGWithStyle defaultPolygonStyle

-- Ingest GeoJSON character stream to rendered SVG XML string
geojsonCharsToSVG : List Char → Maybe String
geojsonCharsToSVG input = do
  svgDoc ← geojsonDocToSVG input
  just (renderXML svgDoc)

-- Ingest GeoJSON String to rendered SVG XML String
geojsonStringToSVG : String → Maybe String
geojsonStringToSVG = geojsonCharsToSVG ∘ toList
