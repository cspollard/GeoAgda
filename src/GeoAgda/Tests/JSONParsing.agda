{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.JSONParsing where

open import Data.List using (List; []; _∷_)

open import Data.String using (toList)
open import Data.Product using (_,_)
open import Data.Sign using (+)
open import Data.Integer using (0ℤ)
open import Data.Maybe using (just)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda

------------------------------------------------------------------------
-- JSON Parser & Round-Trip Tests
------------------------------------------------------------------------

-- Test 1: Literal tokens
_ : parseJSON (toList "null") ≡ just nullⱼ
_ = refl

_ : parseJSON (toList "true") ≡ just trueⱼ
_ = refl

_ : parseJSON (toList "false") ≡ just falseⱼ
_ = refl

_ : parseJSON (toList "\"hello world\"") ≡ just (stringⱼ "hello world")
_ = refl

-- Test 2: Point geometry fixture round-trip
pointFixture : JSON
pointFixture = objectFromList
  ( ("type" , stringⱼ "Point")
  ∷ ("coordinates" , arrayⱼ
      ( numberⱼ (jsonNumber + 10 [] 0ℤ)
      ∷ numberⱼ (jsonNumber + 20 [] 0ℤ)
      ∷ []
      ))
  ∷ []
  )

-- Compile-time verification that parseJSON (printJSON v) ≡ just v
_ : parseJSON (printJSON pointFixture) ≡ just pointFixture
_ = refl

-- Test 3: Parsing raw string with whitespace
rawPointString : List _
rawPointString = toList "{ \"type\" : \"Point\" , \"coordinates\" : [ 10 , 20 ] }"

_ : parseJSON rawPointString ≡ just pointFixture
_ = refl
