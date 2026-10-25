{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Projecting GeoJSON positions to SVG screen coordinates.
module GeoAgda.Rendering.SVG.Projection where

open import Data.String using (String; fromList)
open import Data.Sign using (Sign; +; -)
open import Function using (_∘_)

open import Data.JSON.AST using (JSONNumber; jsonNumber)
open import Data.JSON.Print using (printNumber)
open import GeoAgda.Model.GeoJSON.Types using (Position; pos)

------------------------------------------------------------------------
-- Number Formatting and Sign Manipulation
------------------------------------------------------------------------

oppositeSign : Sign → Sign
oppositeSign + = -
oppositeSign - = +

negateJSONNumber : JSONNumber → JSONNumber
negateJSONNumber (jsonNumber sign integral fraction exponent) =
  jsonNumber (oppositeSign sign) integral fraction exponent

renderJSONNumber : JSONNumber → String
renderJSONNumber = fromList ∘ printNumber

------------------------------------------------------------------------
-- Projected Points & Projections
------------------------------------------------------------------------

record ProjectedPoint : Set where
  constructor projPt
  field
    x : String
    y : String

Projection : Set
Projection = Position → ProjectedPoint

-- Standard Equirectangular (Plate Carrée) projection
-- Longitude maps directly to x; Latitude is inverted (y = -lat)
-- because SVG y-coordinates increase downwards.
equirectangular : Projection
equirectangular (pos lon lat) =
  projPt (renderJSONNumber lon) (renderJSONNumber (negateJSONNumber lat))
