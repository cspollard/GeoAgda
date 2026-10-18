{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Data.JSON.AST where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.Integer.Base using (ℤ)
open import Data.Sign.Base using (Sign; +; -)
open import Data.String.Base using (String)
open import Data.List.Base using (List; []; _∷_; length; lookup)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Unit.Base using (⊤; tt)
open import Data.Fin.Base using (Fin; zero; suc)
open import Function.Base using (_∘_)

------------------------------------------------------------------------
-- JSON Numbers
------------------------------------------------------------------------

-- Exact representation of JSON numbers according to RFC 8259:
--   sign * (integral + fraction * 10^(- length fraction)) * 10^exponent
record JSONNumber : Set where
  constructor jsonNumber
  field
    sign     : Sign
    integral : ℕ
    fraction : List (Fin 10)
    exponent : ℤ

------------------------------------------------------------------------
-- The Inductive JSON AST Type
------------------------------------------------------------------------

-- JSON AST parameterized over variable/leaf type X
data JSON (X : Set) : Set where
  pure          : X → JSON X
  bool          : Bool → JSON X
  number        : JSONNumber → JSON X
  string        : String → JSON X
  arrayFromList : List (JSON X) → JSON X
  objectFromKVs : List (String × JSON X) → JSON X

-- Standard closed JSON values (with terminal leaf ⊤)
JSONValue : Set
JSONValue = JSON ⊤

------------------------------------------------------------------------
-- Smart Constructors
------------------------------------------------------------------------

null : JSONValue
null = pure tt

trueⱼ : ∀ {X} → JSON X
trueⱼ = bool true

falseⱼ : ∀ {X} → JSON X
falseⱼ = bool false
