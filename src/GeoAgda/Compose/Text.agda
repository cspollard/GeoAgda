{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Name clean-up for map labels: ASCII folding, upper case, title case.
module GeoAgda.Compose.Text where

open import Data.Bool using (Bool; true; false; _∧_; if_then_else_)
open import Data.Char using (Char; toℕ; toUpper; toLower; isAlpha)
open import Data.List as List using (List; []; _∷_; concatMap; drop)
open import Data.Maybe using (Maybe; just; nothing)
open import Data.Nat using (ℕ; _≤ᵇ_; _≡ᵇ_; _∸_)
open import Data.String as String using (String; toList; fromList)
open import Function using (_∘_)

------------------------------------------------------------------------
-- ASCII folding
------------------------------------------------------------------------

-- Latin-1 letters U+00C0 … U+00FF without their accents (ligatures and
-- symbols are folded to a single letter or dropped).
private
  latin1 : List Char
  latin1 = toList "AAAAAAACEEEEIIIIDNOOOOO.OUUUUYTsaaaaaaaceeeeiiiidnooooo.ouuuuyty"

  nth : ℕ → List Char → Maybe Char
  nth n xs with drop n xs
  ... | []    = nothing
  ... | c ∷ _ = just c

-- Letters in Latin Extended-A that occur in Natural Earth names.
extraFold : ℕ → Maybe Char
extraFold n =
  if n ≡ᵇ 257 then just 'a'        -- ā
  else if n ≡ᵇ 283 then just 'e'   -- ě
  else if n ≡ᵇ 382 then just 'z'   -- ž
  else nothing

foldChar : Char → List Char
foldChar c = go (toℕ c)
  where
    go : ℕ → List Char
    go n = if n ≤ᵇ 127 then c ∷ []
           else if (192 ≤ᵇ n) ∧ (n ≤ᵇ 255)
           then (case nth (n ∸ 192) latin1 of λ { (just '.') → [] ; (just x) → x ∷ [] ; nothing → [] })
           else (case extraFold n of λ { (just x) → x ∷ [] ; nothing → [] })
      where case_of_ : ∀ {A B : Set} → A → (A → B) → B
            case x of f = f x

-- Drop accents; characters with no ASCII counterpart are removed.
asciiFold : String → String
asciiFold = fromList ∘ concatMap foldChar ∘ toList

------------------------------------------------------------------------
-- Case
------------------------------------------------------------------------

upper : String → String
upper = String.map toUpper

-- "great PLAINS" ↦ "Great Plains": a letter after a non-letter is upper-cased,
-- other letters lower-cased.
title : String → String
title = fromList ∘ go false ∘ toList
  where
    go : Bool → List Char → List Char
    go _    []       = []
    go prev (c ∷ cs) =
      if isAlpha c
      then (if prev then toLower c else toUpper c) ∷ go true cs
      else c ∷ go false cs
