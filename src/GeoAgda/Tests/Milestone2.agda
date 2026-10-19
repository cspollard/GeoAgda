{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone2 where

open import Data.List using ([]; _∷_)
open import Data.Fin using (zero; suc)
open import Data.Product using (_,_)
open import Data.Maybe using (just)
open import Data.Unit using (tt)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda

------------------------------------------------------------------------
-- Invertible Parsing Tests
------------------------------------------------------------------------

-- Test 1: Round-trip exact parsing for single digits
_ : parseExact digitParser ('5' ∷ []) ≡ just (suc (suc (suc (suc (suc zero)))))
_ = refl

_ : roundTripExact digitParser (suc (suc zero)) ≡ refl
_ = refl

-- Test 2: Literal character parsing and round-trip
_ : parseExact (litChar '{') ('{' ∷ []) ≡ just tt
_ = refl

_ : roundTripExact (litChar ':') tt ≡ refl
_ = refl

-- Test 3: Sequential composition of invertible parsers (_⨂_)
colonDigitParser = litChar ':' ⨂ digitParser

_ : parseExact colonDigitParser (':' ∷ '7' ∷ []) ≡ just (tt , suc (suc (suc (suc (suc (suc (suc zero)))))))
_ = refl

_ : roundTripExact colonDigitParser (tt , suc zero) ≡ refl
_ = refl

-- Test 4: Horner's method natural number conversion
_ : digitsToNat (suc zero ∷ zero ∷ zero ∷ []) ≡ 100
_ = refl
