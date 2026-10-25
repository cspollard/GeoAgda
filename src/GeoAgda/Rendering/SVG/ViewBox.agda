{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- SVG `viewBox` computation from a GeoJSON bounding box.
module GeoAgda.Rendering.SVG.ViewBox where

open import Data.Nat using (ℕ; zero; suc; _/_; _%_)
import Data.Nat.Show as NatShow
open import Data.String as String using (String)
open import Data.Integer as ℤ using (ℤ)
open import Data.List using (_∷_; [])
open import Function using (case_of_)

open import Data.JSON.AST using (JSONNumber)
open import GeoAgda.Model.GeoJSON.Types using (BBox; bbox)
open import GeoAgda.Rendering.SVG.Projection using (renderJSONNumber; negateJSONNumber)
open import GeoAgda.Rendering.SVG.Scaled

-- Format the SVG viewBox attribute "minX minY width height"
formatViewBox : (minX minY width height : String) → String
formatViewBox minX minY w h = String.unwords (minX ∷ minY ∷ w ∷ h ∷ [])

formatScaledDiff : ℕ → String
formatScaledDiff diffℕ =
  let intPart = diffℕ / 10000
      fracPart = (diffℕ % 10000) / 100
  in case fracPart of λ where
       zero    → NatShow.show intPart
       (suc _) → String._++_ (NatShow.show intPart) (String._++_ "." (NatShow.show fracPart))

computePositiveDiff : JSONNumber → JSONNumber → String
computePositiveDiff n₁ n₂ =
  let v₁ = jsonNumberToScaledℤ n₁
      v₂ = jsonNumberToScaledℤ n₂
      diffℤ = v₂ ℤ.- v₁
  in formatScaledDiff (ℤ.∣ diffℤ ∣)

record ViewBox : Set where
  constructor viewBox
  field
    minX   : String
    minY   : String
    width  : String
    height : String

viewBoxToString : ViewBox → String
viewBoxToString (viewBox minX minY w h) = formatViewBox minX minY w h

defaultWorldViewBoxRec : ViewBox
defaultWorldViewBoxRec = viewBox "-180" "-90" "360" "180"

-- Format viewBox from a GeoJSON BBox under equirectangular projection
viewBoxComponentsFromBBox : BBox → ViewBox
viewBoxComponentsFromBBox (bbox minLon minLat maxLon maxLat) =
  viewBox
    (renderJSONNumber minLon)
    (renderJSONNumber (negateJSONNumber maxLat))
    (computePositiveDiff minLon maxLon)
    (computePositiveDiff minLat maxLat)
