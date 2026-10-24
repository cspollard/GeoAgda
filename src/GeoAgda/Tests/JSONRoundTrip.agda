{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

------------------------------------------------------------------------
-- JSON printing, parsing and the round-trip theorem: fixtures
--
-- Concrete checks are `refl` proofs (they run the printer and parser at
-- type-checking time); the universal statements are the theorems of
-- `Data.JSON.RoundTrip`.  Equality of parsed values is up to `_≈ⱼ_`, so
-- concrete parses are compared through their rendering.
------------------------------------------------------------------------

module GeoAgda.Tests.JSONRoundTrip where

open import Data.Fin.Patterns using (1F; 2F; 5F)
open import Data.Integer using (+_; -[1+_])
open import Data.List using (List; []; _∷_)
open import Data.Maybe as Maybe using (Maybe; just; nothing)
open import Data.Product using (_,_; ∃; _×_)
import Data.Sign as Sign
open import Data.String using (String; toList)
open import Function.Bundles using (RightInverse)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Data.JSON.AST
open import Data.JSON.Equality using (_≈ⱼ_; JSONSetoid)
open import Data.JSON.Number using (jsonNumber)
open import Data.JSON.Print using (renderJSON; printJSON)
open import Data.JSON.RoundTrip

-- Parse some text and render the result compactly.
normalise : String → Maybe String
normalise s = Maybe.map renderJSON (parseJSON (toList s))

------------------------------------------------------------------------
-- Printing
------------------------------------------------------------------------

_ : renderJSON nullⱼ ≡ "null"
_ = refl

_ : renderJSON (arrayⱼ (trueⱼ ∷ falseⱼ ∷ nullⱼ ∷ [])) ≡ "[true,false,null]"
_ = refl

_ : renderJSON (numberⱼ (jsonNumber Sign.- 42 (1F ∷ 2F ∷ 5F ∷ []) (+_ 3))) ≡ "-42.125e+3"
_ = refl

-- Quotes, backslashes and newlines are escaped.
_ : renderJSON (stringⱼ "a\"b\\c\n") ≡ "\"a\\\"b\\\\c\\n\""
_ = refl

-- Duplicate keys are kept (RFC 8259 §4: names SHOULD be unique).
_ : renderJSON (objectFromList (("k" , trueⱼ) ∷ ("k" , falseⱼ) ∷ []))
      ≡ "{\"k\":true,\"k\":false}"
_ = refl

------------------------------------------------------------------------
-- Parsing
------------------------------------------------------------------------

_ : normalise "null" ≡ just "null"
_ = refl

-- White space is ignored, and printing is compact.
_ : normalise "{ \"type\" : \"Point\" , \"coordinates\" : [ 10 , 20 ] }"
      ≡ just "{\"type\":\"Point\",\"coordinates\":[10,20]}"
_ = refl

_ : normalise "[ [ ] , { } , [ -1.5e-3 ] ]" ≡ just "[[],{},[-1.5e-3]]"
_ = refl

_ : normalise "\"line\\nbreak \\\"quoted\\\"\"" ≡ just "\"line\\nbreak \\\"quoted\\\"\""
_ = refl

-- Malformed input is rejected.
_ : parseJSON (toList "[1,") ≡ nothing
_ = refl

_ : parseJSON (toList "{\"a\" 1}") ≡ nothing
_ = refl

-- Two adjacent numbers are not a value.
_ : parseJSON (toList "1 2") ≡ nothing
_ = refl

------------------------------------------------------------------------
-- The round-trip theorem
------------------------------------------------------------------------

-- Partial parser: every printed value parses back to a bisimilar one.
roundTrip : ∀ v → ∃ λ v′ → parseJSON (printJSON v) ≡ just v′ × v′ ≈ⱼ v
roundTrip = parseJSON-printJSON

-- Total parser, as a standard-library `RightInverse`:
-- `from (to v) ≈ⱼ v`.
retraction : ∀ v → RightInverse.from jsonStage (RightInverse.to jsonStage v) ≈ⱼ v
retraction v = RightInverse.inverseʳ jsonStage refl
