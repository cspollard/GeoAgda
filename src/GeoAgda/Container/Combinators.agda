{-# OPTIONS --safe --cubical-compatible #-}

module GeoAgda.Container.Combinators where

open import Level using (Level; 0ℓ)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.Fin.Base using (Fin; zero; suc)
open import Data.List.Base as List using (List; []; _∷_; _++_)
open import Data.Char.Base using (Char)
open import Function.Base using (_∘_)

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
