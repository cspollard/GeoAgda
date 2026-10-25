{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Fixed-point arithmetic: coordinates scaled by 10⁴ as integers.
module GeoAgda.Rendering.SVG.Scaled where

open import Data.Bool using (Bool; true; false; if_then_else_)
open import Data.Nat as ℕ using (ℕ; suc; _*_; _/_; _%_; _<ᵇ_) renaming (_+_ to _+ℕ_)
open import Data.Nat.DivMod using (_mod_)
open import Data.Integer using (ℤ; +_; -[1+_])
open import Data.Sign using (Sign)
open import Data.Fin as Fin using (Fin)
open import Data.List using (List; []; _∷_)

open import Data.JSON.AST using (JSONNumber; jsonNumber)
open import Data.JSON.Number using (signNatToℤ)

-- Convert JSONNumber to scaled integer (scaling fraction by factor of 10000)
scaleFraction : List (Fin 10) → ℕ
scaleFraction = go 1000
  where
    -- the first four digits get weights 1000, 100, 10, 1; later digits weigh 0
    go : ℕ → List (Fin 10) → ℕ
    go _ []       = 0
    go w (d ∷ ds) = Fin.toℕ d * w +ℕ go (w / 10) ds

jsonNumberToScaledℤ : JSONNumber → ℤ
jsonNumberToScaledℤ (jsonNumber sign integral fraction _) =
  signNatToℤ sign ((integral * 10000) +ℕ scaleFraction fraction)

-- The last decimal digit of a natural number
natToFin10 : ℕ → Fin 10
natToFin10 n = n mod 10

halfℤ : ℤ → ℤ
halfℤ (+_ n)   = +_ (n / 2)
halfℤ -[1+ n ] = -[1+ (n / 2) ]

scaledℤToJSONNumber : ℤ → JSONNumber
scaledℤToJSONNumber (+_ n) =
  let intPart = n / 10000
      rem     = n % 10000
      d₁      = natToFin10 ((rem / 1000) % 10)
      d₂      = natToFin10 ((rem / 100) % 10)
  in jsonNumber Sign.+ intPart (d₁ ∷ d₂ ∷ []) (+_ 0)
scaledℤToJSONNumber -[1+ n ] =
  let m       = suc n
      intPart = m / 10000
      rem     = m % 10000
      d₁      = natToFin10 ((rem / 1000) % 10)
      d₂      = natToFin10 ((rem / 100) % 10)
  in jsonNumber Sign.- intPart (d₁ ∷ d₂ ∷ []) (+_ 0)

-- Min and max of scaled coordinates.  The stdlib `_⊓_`/`_⊔_` on ℤ recurse on
-- the magnitude (unary), which makes them cost ~10⁶ steps on a coordinate
-- like 180.0 (scaled by 10⁴); these use the primitive `_<ᵇ_` instead.
private
  _<ᶻ_ : ℤ → ℤ → Bool
  (+_ m)   <ᶻ (+_ n)   = m <ᵇ n
  (+_ _)   <ᶻ -[1+ _ ] = false
  -[1+ _ ] <ᶻ (+_ _)   = true
  -[1+ m ] <ᶻ -[1+ n ] = n <ᵇ m

minℤ maxℤ : ℤ → ℤ → ℤ
minℤ x y = if y <ᶻ x then y else x
maxℤ x y = if x <ᶻ y then y else x
