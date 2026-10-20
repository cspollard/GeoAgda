{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}


module GeoAgda.Container.Combinators where

open import Level using (Level; 0ℓ)
open import Data.Nat using (ℕ; zero; suc)
open import Data.Fin using (Fin; zero; suc)
open import Data.List as List using (List; []; _∷_; _++_)
open import Data.Char using (Char)
open import Function using (_∘_)

private
  variable
    a : Level
    A : Set a

------------------------------------------------------------------------
-- Finite Tabulation Combinators
------------------------------------------------------------------------

-- Tabulate a finite family of elements into a standard list
tabulateFin : (n : ℕ) → (Fin n → A) → List A
tabulateFin zero    _ = []
tabulateFin (suc n) f = f zero ∷ tabulateFin n (f ∘ suc)

------------------------------------------------------------------------
-- List Intersperse
------------------------------------------------------------------------

-- Intersperse a separator character between lists of characters
intersperseChar : Char → List (List Char) → List Char
intersperseChar _   []           = []
intersperseChar _   (x ∷ [])     = x
intersperseChar sep (x ∷ y ∷ xs) = x ++ (sep ∷ intersperseChar sep (y ∷ xs))
