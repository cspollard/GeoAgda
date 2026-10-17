{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Data.JSON.Schema where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Char.Base using (Char)
open import Data.String.Base as String using (String)

open import Data.String.Properties using (_≟_)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.List.Base as List using (List; []; _∷_; map)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe.Base as Maybe using (Maybe; just; nothing)
open import Data.Unit.Base using (⊤; tt)
open import Data.Empty using (⊥; ⊥-elim)
open import Data.Fin.Base using (Fin; zero; suc)
open import Relation.Nullary.Decidable using (Dec; yes; no)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda.Container.Combinators using (tabulateFin)
open import GeoAgda.Data.JSON.AST

------------------------------------------------------------------------
-- JSON Unpacking / Projections
------------------------------------------------------------------------

asNull : JSONValue → Maybe ⊤
asNull (impure (nullₛ , _)) = just tt
asNull _                   = nothing

asBool : JSONValue → Maybe Bool
asBool (impure (boolₛ b , _)) = just b
asBool _                     = nothing

asNumber : JSONValue → Maybe JSONNumber
asNumber (impure (numberₛ n , _)) = just n
asNumber _                       = nothing

asString : JSONValue → Maybe String
asString (impure (stringₛ s , _)) = just s
asString _                       = nothing

asArray : JSONValue → Maybe (List JSONValue)
asArray (impure (arrayₛ n , rec)) = just (tabulateFin n rec)
asArray _                         = nothing

formatPairs : (keys : List String) → (Fin (List.length keys) → JSONValue) → List (String × JSONValue)
formatPairs []       _   = []
formatPairs (k ∷ ks) rec = (k , rec zero) ∷ formatPairs ks (rec ∘ suc)
  where open import Function.Base using (_∘_)

asObject : JSONValue → Maybe (List (String × JSONValue))
asObject (impure (objectₛ keys , rec)) = just (formatPairs keys rec)
asObject _                             = nothing

------------------------------------------------------------------------
-- Field Lookup in Association Lists
------------------------------------------------------------------------

lookupField : String → List (String × JSONValue) → Maybe JSONValue
lookupField _ [] = nothing
lookupField key ((k , v) ∷ kvs) with key ≟ k
... | yes _ = just v
... | no  _ = lookupField key kvs

------------------------------------------------------------------------
-- Lightweight Schema Definitions
------------------------------------------------------------------------

data Schema : Set where
  sAny    : Schema
  sNull   : Schema
  sBool   : Schema
  sNumber : Schema
  sString : Schema
  sArray  : Schema → Schema
  sObject : List (String × Schema) → Schema

-- Decidable schema check procedure
mutual
  checkSchema : JSONValue → Schema → Bool
  checkSchema _ sAny    = true
  checkSchema v sNull   with asNull v
  ... | just _ = true
  ... | nothing = false
  checkSchema v sBool   with asBool v
  ... | just _ = true
  ... | nothing = false
  checkSchema v sNumber with asNumber v
  ... | just _ = true
  ... | nothing = false
  checkSchema v sString with asString v
  ... | just _ = true
  ... | nothing = false
  checkSchema v (sArray elemS) with asArray v
  ... | nothing    = false
  ... | just elems = checkArrayElements elems elemS
  checkSchema v (sObject reqs) with asObject v
  ... | nothing  = false
  ... | just kvs = checkObjectFields kvs reqs

  checkArrayElements : List JSONValue → Schema → Bool
  checkArrayElements [] _ = true
  checkArrayElements (x ∷ xs) s with checkSchema x s
  ... | true  = checkArrayElements xs s
  ... | false = false

  checkObjectFields : List (String × JSONValue) → List (String × Schema) → Bool
  checkObjectFields _ [] = true
  checkObjectFields kvs ((k , s) ∷ reqs) with lookupField k kvs
  ... | nothing = false
  ... | just v  with checkSchema v s
  ...   | true  = checkObjectFields kvs reqs
  ...   | false = false
