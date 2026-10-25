{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- SVG `points` and path-data (`d`) attribute formatting.
module GeoAgda.Rendering.SVG.PathData where

open import Data.Char using (Char)
open import Data.String using (String; toList; fromList)
open import Data.List using (List; []; _∷_; _++_; concat; map; intersperse)
open import Function using (_∘_)

open import GeoAgda.Model.GeoJSON.Types using (Position)
open import GeoAgda.Rendering.SVG.Projection

------------------------------------------------------------------------
-- Formatting Points for SVG Attributes
------------------------------------------------------------------------

-- Format a single projected point as "x,y"
formatPointPair : ProjectedPoint → List Char
formatPointPair (projPt x y) = toList x ++ (',' ∷ toList y)

-- Format a list of positions as SVG points attribute: "x1,y1 x2,y2 ..."
formatPointsList : Projection → List Position → List Char
formatPointsList proj pts =
  concat (intersperse (' ' ∷ []) (map (formatPointPair ∘ proj) pts))

formatPoints : Projection → List Position → String
formatPoints proj pts = fromList (formatPointsList proj pts)

------------------------------------------------------------------------
-- Formatting SVG Path Data ("d" attribute)
------------------------------------------------------------------------

private
  formatPathLines : Projection → List Position → List Char
  formatPathLines proj []       = []
  formatPathLines proj (p ∷ ps) =
    ' ' ∷ 'L' ∷ ' ' ∷ formatPointPair (proj p) ++ formatPathLines proj ps

-- Formats a closed linear ring as "M x0 y0 L x1 y1 ... Z"
formatRingD : Projection → List Position → List Char
formatRingD proj []       = []
formatRingD proj (p ∷ ps) =
  'M' ∷ ' ' ∷ formatPointPair (proj p) ++ formatPathLines proj ps ++ (' ' ∷ 'Z' ∷ [])

-- Formats a polygon (outer ring + inner rings) into path data
formatPolygonD : Projection → List (List Position) → String
formatPolygonD proj rings =
  fromList (concat (intersperse (' ' ∷ []) (map (formatRingD proj) rings)))

-- Formats a multi-polygon into path data
formatMultiPolygonD : Projection → List (List (List Position)) → String
formatMultiPolygonD proj polys =
  fromList (concat (intersperse (' ' ∷ []) (map (toList ∘ formatPolygonD proj) polys)))
