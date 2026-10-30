{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Exact fixed-point coordinates: an `ℤ` counts units of 10⁻¹⁵ degrees.
--
-- A JSON number is a decimal, so it is represented exactly whenever it has at most
-- `digits` fraction digits once its exponent is applied.  Further digits are rounded
-- (half away from zero): 10⁻¹⁵° is below the resolution of the doubles the data was
-- printed from (Natural Earth has 16–17 digit numbers such as 5.4762976217799997).
-- The largest coordinate, 180·10¹⁵, is below 2⁶³, so a value is one machine word.
--
-- This is the stored form of a `Path` (`GeoAgda.Rendering.SVG.Path`); `Scaled.agda` is
-- the older, lossy ×10⁴ form used by `Simplify`.
module GeoAgda.Model.Exact where

open import Data.Bool using (Bool; true; false; if_then_else_)
open import Data.Fin as Fin using (Fin)
open import Data.Integer as ℤ using (ℤ; +_; -[1+_])
open import Data.List using (List; []; _∷_; length; reverse)
open import Data.Maybe as Maybe using (Maybe; just; nothing)
open import Data.Nat as ℕ using (ℕ; zero; suc; _*_; _/_; _%_; _^_; _≤ᵇ_; _≡ᵇ_) renaming (_+_ to _+ℕ_)
open import Data.Nat.DivMod using (_mod_)
open import Data.Nat.Properties using (m^n≢0)
open import Data.Product using (_×_; _,_)
open import Data.Sign using (Sign)
import Data.Sign as Sign

open import Data.JSON.AST using (JSONNumber; jsonNumber)
open import Data.JSON.Number using (signNatToℤ)
open import GeoAgda.Model.GeoJSON.Types using (Position; pos)
open import GeoAgda.Model.Path using (Pt)

-- Fraction digits kept.
digits : ℕ
digits = 15

Scale : ℕ
Scale = 10 ^ digits

-- Decimal shifts beyond this are rejected (`toExact` gives `nothing`); they keep `10 ^ _` small.
maxShift : ℕ
maxShift = 64

------------------------------------------------------------------------
-- JSON number → exact integer
------------------------------------------------------------------------

-- The integral part followed by the fraction digits, as one natural.
mantissa : ℕ → List (Fin 10) → ℕ
mantissa i []       = i
mantissa i (d ∷ ds) = mantissa (i * 10 +ℕ Fin.toℕ d) ds

-- `m · 10^s` for `s ∈ ℤ`, rounded to a natural.
shiftBy : ℤ → ℕ → Maybe ℕ
shiftBy s m with m ≡ᵇ 0
... | true  = just 0
... | false with s
...   | + k      = if k ≤ᵇ maxShift then just (m * 10 ^ k) else nothing
...   | -[1+ k ] = if suc k ≤ᵇ maxShift
                     then just (_/_ (m +ℕ 10 ^ suc k / 2) (10 ^ suc k) ⦃ m^n≢0 10 (suc k) ⦄)
                     else just 0

toExact : JSONNumber → Maybe ℤ
toExact (jsonNumber sign integral fraction exponent) =
  Maybe.map (signNatToℤ sign)
    (shiftBy ((+ digits) ℤ.+ exponent ℤ.- (+ length fraction)) (mantissa integral fraction))

------------------------------------------------------------------------
-- Exact integer → JSON number
------------------------------------------------------------------------

private
  -- the last `k` decimal digits of `n`, least significant first
  lsdFirst : ℕ → ℕ → List (Fin 10)
  lsdFirst zero    n = []
  lsdFirst (suc k) n = (n mod 10) ∷ lsdFirst k (n / 10)

  dropZeros : List (Fin 10) → List (Fin 10)
  dropZeros []       = []
  dropZeros (d ∷ ds) with Fin.toℕ d ≡ᵇ 0
  ... | true  = dropZeros ds
  ... | false = d ∷ ds

  fromMagnitude : Sign → ℕ → JSONNumber
  fromMagnitude s n =
    jsonNumber s (n / Scale) (reverse (dropZeros (lsdFirst digits (n % Scale)))) (+ 0)

fromExact : ℤ → JSONNumber
fromExact (+ n)    = fromMagnitude Sign.+ n
fromExact -[1+ n ] = fromMagnitude Sign.- (suc n)

------------------------------------------------------------------------
-- Points
------------------------------------------------------------------------

toExactPt : Position → Maybe Pt
toExactPt (pos lon lat) with toExact lon | toExact lat
... | just x | just y = just (x , y)
... | _      | _      = nothing

fromExactPt : Pt → Position
fromExactPt (x , y) = pos (fromExact x) (fromExact y)
