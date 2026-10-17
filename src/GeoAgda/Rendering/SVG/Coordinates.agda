{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Rendering.SVG.Coordinates where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Char.Base using (Char)
open import Data.String.Base as String using (String; toList; fromList)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.Integer.Base using (ℤ; +_; -[1+_])
open import Data.Sign.Base using (Sign; +; -)
open import Data.Fin.Base using (Fin)
open import Data.List.Base as List using (List; []; _∷_; _++_; concat; map; intersperse)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Function.Base using (_∘_; _$_)

open import GeoAgda.Data.JSON.AST using (JSONNumber; jsonNumber)
open import GeoAgda.Data.JSON.Print using (printNumber)
open import GeoAgda.Model.GeoJSON.Types using (Position; pos; BBox; bbox)

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

------------------------------------------------------------------------
-- ViewBox Formatting
------------------------------------------------------------------------

-- Format standard SVG viewBox attribute "minX minY width height"
formatViewBox : (minX minY width height : String) → String
formatViewBox minX minY w h =
  String._++_ minX (String._++_ " " (String._++_ minY (String._++_ " " (String._++_ w (String._++_ " " h)))))

-- Default world viewBox spanning -180 to 180 lon and -90 to 90 lat
defaultWorldViewBox : String
defaultWorldViewBox = formatViewBox "-180" "-90" "360" "180"

-- Format viewBox from a GeoJSON BBox under equirectangular projection
viewBoxFromBBox : BBox → String
viewBoxFromBBox (bbox minLon minLat maxLon maxLat) =
  formatViewBox
    (renderJSONNumber minLon)
    (renderJSONNumber (negateJSONNumber maxLat))
    (renderJSONNumber maxLon)
    (renderJSONNumber (negateJSONNumber minLat))
