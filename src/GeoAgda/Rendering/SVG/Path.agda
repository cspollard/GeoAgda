{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Rendering a `Path` as the `d` attribute of an SVG path; see plans/PathPlan.md.  The
-- projection is applied here, when printing.
module GeoAgda.Rendering.SVG.Path where

open import Data.Char using (Char)
open import Data.Empty using (⊥)
open import Data.List using (List; []; _∷_; _++_)
open import Data.Product using (_,_)
open import Data.Unit using (⊤; tt)
open import Data.Container using (⟦_⟧)
open import Data.Container.FreeMonad using (foldr)
open import Data.Integer using (ℤ)

open import GeoAgda.Model.Exact using (fromExactPt)
open import GeoAgda.Model.Path public
open import GeoAgda.Rendering.SVG.PathData using (formatPointPair)
open import GeoAgda.Rendering.SVG.Projection using (Projection)

------------------------------------------------------------------------
-- Rendering: the algebra `⟦ PathC ⟧ (List Char) → List Char`
------------------------------------------------------------------------

-- A space before the rest unless there is none.
sep : List Char → List Char
sep []         = []
sep s@(_ ∷ _)  = ' ' ∷ s

point : Projection → ℤ → ℤ → List Char
point proj x y = formatPointPair (proj (fromExactPt (x , y)))

-- Print one command, then a space and the printed rest unless the rest is empty.
renderAlg : Projection → ⟦ PathC ⟧ (List Char) → List Char
renderAlg proj (moveTo x y , r) = 'M' ∷ ' ' ∷ point proj x y ++ sep (r tt)
renderAlg proj (lineTo x y , r) = 'L' ∷ ' ' ∷ point proj x y ++ sep (r tt)
renderAlg proj (close      , r) = 'Z' ∷ sep (r tt)
renderAlg proj (stop       , r) = []

-- Rendering with a printer for the leaves.
renderWith : ∀ {A : Set} → Projection → (A → List Char) → PathM A → List Char
renderWith proj f = foldr f (renderAlg proj)

-- The `d` attribute of a complete path.
renderPath : Projection → Path → List Char
renderPath proj = renderWith proj (λ ())

-- The same for a fragment (nothing follows it).
renderM : Projection → PathM ⊤ → List Char
renderM proj = renderWith proj (λ _ → [])
