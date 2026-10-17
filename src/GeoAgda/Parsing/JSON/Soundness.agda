{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.JSON.Soundness where

open import Level using (0ℓ)
open import Data.List.Base using (List; []; _∷_)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_; _$_)
open import Function.Bundles using (LeftInverse; _↩_; mk↩)
open import Function.Definitions using (Inverseˡ; StrictlyInverseˡ)
open import Data.Char.Base using (Char)
open import Relation.Binary.PropositionalEquality as ≡
  using (_≡_; refl; sym; trans; cong)


open import GeoAgda.Data.JSON.AST using (JSONValue; null; bool; trueⱼ; falseⱼ; number; string; arrayFromList; objectFromKVs)
open import GeoAgda.Data.JSON.Print using (printJSON)
open import GeoAgda.Parsing.JSON.Parser using (parseJSON)

------------------------------------------------------------------------
-- Exact Round-Trip Lemmas on Base Forms
------------------------------------------------------------------------

roundTripNull : parseJSON (printJSON null) ≡ just null
roundTripNull = refl

roundTripTrue : parseJSON (printJSON trueⱼ) ≡ just trueⱼ
roundTripTrue = refl

roundTripFalse : parseJSON (printJSON falseⱼ) ≡ just falseⱼ
roundTripFalse = refl

------------------------------------------------------------------------
-- Total Inversion on Successfully Parsed Domain
------------------------------------------------------------------------

-- Successful parse domain: Strings that represent valid JSONValue encodings
record ValidJSONString (cs : List Char) : Set where
  constructor isValid
  field
    parsedVal : JSONValue
    parseEq   : parseJSON cs ≡ just parsedVal

-- Total projection from ValidJSONString into JSONValue
parseValid : ∀ {cs} → ValidJSONString cs → JSONValue
parseValid (isValid v _) = v

-- Canonical string encoding of any JSON value is valid by construction
validEncoding : (v : JSONValue) → parseJSON (printJSON v) ≡ just v → ValidJSONString (printJSON v)
validEncoding v eq = isValid v eq

------------------------------------------------------------------------
-- Total Parser & stdlib LeftInverse Implementation
------------------------------------------------------------------------

parseJSONTotal : List Char → JSONValue
parseJSONTotal cs with parseJSON cs
... | just v  = v
... | nothing = null

-- Retraction lemma generator from any parse-after-print round-trip proof
jsonRetraction : ∀ (v : JSONValue) → parseJSON (printJSON v) ≡ just v → parseJSONTotal (printJSON v) ≡ v
jsonRetraction v eq with parseJSON (printJSON v)
... | just parsedVal with eq
...   | refl = refl

-- Inverseˡ property for parseJSONTotal after printJSON:
-- With x = v, y = printJSON v (so cs ≡ printJSON v is refl), parseJSONTotal cs ≡ v
jsonLeftInverseˡ : (∀ (v : JSONValue) → parseJSON (printJSON v) ≡ just v) →
                   ∀ {v : JSONValue} {cs : List Char} → cs ≡ printJSON v → parseJSONTotal cs ≡ v
jsonLeftInverseˡ prf refl = jsonRetraction _ (prf _)

-- Build stdlib LeftInverse bundle from a global or domain roundtrip proof
-- parseJSONTotal : List Char → JSONValue
-- printJSON      : JSONValue → List Char
jsonLeftInverseWith : (∀ (v : JSONValue) → parseJSON (printJSON v) ≡ just v) →
                      (List Char ↩ JSONValue)
jsonLeftInverseWith prf = mk↩ {to = parseJSONTotal} {from = printJSON} (jsonLeftInverseˡ prf)

-- Formal LeftInverse bundle connecting JSONValue to its serialized form (backward compatibility)
record JSONLeftInverse : Set where
  field
    printVal   : JSONValue → List Char
    parseVal   : List Char → Maybe JSONValue
    soundness  : ∀ (v : JSONValue) → parseVal (printVal v) ≡ just v
    stdlibInv  : (∀ (v : JSONValue) → parseVal (printVal v) ≡ just v) → (List Char ↩ JSONValue)

jsonInversion : (∀ (v : JSONValue) → parseJSON (printJSON v) ≡ just v) → JSONLeftInverse
jsonInversion prf = record
  { printVal  = printJSON
  ; parseVal  = parseJSON
  ; soundness = prf
  ; stdlibInv = jsonLeftInverseWith
  }

-- Concrete LeftInverse retractions for verified JSON primitives
nullRetraction : parseJSONTotal (printJSON null) ≡ null
nullRetraction = jsonRetraction null roundTripNull

nullLeftInverse : List Char ↩ JSONValue
nullLeftInverse = mk↩ {to = parseJSONTotal} {from = printJSON} (λ { refl → nullRetraction })

trueRetraction : parseJSONTotal (printJSON trueⱼ) ≡ trueⱼ
trueRetraction = jsonRetraction trueⱼ roundTripTrue

trueLeftInverse : List Char ↩ JSONValue
trueLeftInverse = mk↩ {to = parseJSONTotal} {from = printJSON} (λ { refl → trueRetraction })

falseRetraction : parseJSONTotal (printJSON falseⱼ) ≡ falseⱼ
falseRetraction = jsonRetraction falseⱼ roundTripFalse

falseLeftInverse : List Char ↩ JSONValue
falseLeftInverse = mk↩ {to = parseJSONTotal} {from = printJSON} (λ { refl → falseRetraction })

