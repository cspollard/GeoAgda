{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- End-to-end ingestion: GeoJSON text → SVG.
module GeoAgda.Pipeline where

open import Data.Char using (Char)
open import Data.String using (String; toList)
open import Data.List using (List)
open import Data.Maybe using (Maybe; just; _>>=_)

open import Data.XML.AST using (XMLDoc)
open import Data.XML.Print using (renderXML)
open import Data.JSON.RoundTrip using (parseJSON)
open import GeoAgda.Model.GeoJSON.Extraction using (extractFeatureCollection)
open import GeoAgda.Rendering.SVG.Style using (SVGStyle; defaultTerrainStyle)
open import GeoAgda.Rendering.SVG.Render using (renderMapSVG)

-- GeoJSON characters to an SVG document, in the given style.
geojsonToSVGDoc : SVGStyle → List Char → Maybe XMLDoc
geojsonToSVGDoc style input = do
  json ← parseJSON input
  fc   ← extractFeatureCollection json
  just (renderMapSVG style fc)

-- GeoJSON text to SVG text, in the given style.
geojsonToSVG : SVGStyle → String → Maybe String
geojsonToSVG style input = do
  doc ← geojsonToSVGDoc style (toList input)
  just (renderXML doc)

-- … in the default terrain style.
geojsonStringToSVG : String → Maybe String
geojsonStringToSVG = geojsonToSVG defaultTerrainStyle
