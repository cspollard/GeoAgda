{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.JSON.Parser where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Char.Base using (Char)
open import Data.String.Base as String using (String)
open import Data.Nat.Base as ℕ using (ℕ; zero; suc)
open import Data.List.Base as List using (List; []; _∷_; length)
open import Data.Product.Base using (_×_; _,_)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_; _$_)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda.Data.JSON.AST
  using (JSONValue; null; bool; number; string; arrayFromList; objectFromKVs)
open import GeoAgda.Parsing.JSON.Lexer
  using (JSONToken; lbraceT; rbraceT; lbracketT; rbracketT; colonT; commaT; nullT; boolT; numberT; stringT; tokenize)

------------------------------------------------------------------------
-- Mutual Recursive-Descent Parser
------------------------------------------------------------------------

mutual
  parseValue : ℕ → List JSONToken → Maybe (JSONValue × List JSONToken)
  parseValue zero _ = nothing
  parseValue (suc fuel) (nullT ∷ rest)      = just (null , rest)
  parseValue (suc fuel) (boolT b ∷ rest)    = just (bool b , rest)
  parseValue (suc fuel) (numberT n ∷ rest)  = just (number n , rest)
  parseValue (suc fuel) (stringT s ∷ rest)  = just (string s , rest)
  parseValue (suc fuel) (lbracketT ∷ rest) with parseArrayElements fuel rest
  ... | nothing          = nothing
  ... | just (arr , rem) = just (arrayFromList arr , rem)
  parseValue (suc fuel) (lbraceT ∷ rest) with parseObjectEntries fuel rest
  ... | nothing          = nothing
  ... | just (kvs , rem) = just (objectFromKVs kvs , rem)
  parseValue (suc fuel) _                   = nothing

  continueArray : ℕ → JSONValue → List JSONToken → Maybe (List JSONValue × List JSONToken)
  continueArray fuel v (rbracketT ∷ rest) = just (v ∷ [] , rest)
  continueArray fuel v (commaT ∷ rest) with parseArrayElements fuel rest
  ... | just (vs , rem') = just (v ∷ vs , rem')
  ... | nothing          = nothing
  continueArray _ _ _ = nothing

  parseArrayElements : ℕ → List JSONToken → Maybe (List JSONValue × List JSONToken)
  parseArrayElements zero _ = nothing
  parseArrayElements (suc fuel) [] = nothing
  parseArrayElements (suc fuel) (rbracketT ∷ rest) = just ([] , rest)
  parseArrayElements (suc fuel) toks with parseValue fuel toks
  ... | just (v , rem) = continueArray fuel v rem
  ... | nothing        = nothing

  continueObject : ℕ → String → JSONValue → List JSONToken → Maybe (List (String × JSONValue) × List JSONToken)
  continueObject fuel k v (rbraceT ∷ rem') = just ((k , v) ∷ [] , rem')
  continueObject fuel k v (commaT ∷ rem') with parseObjectEntries fuel rem'
  ... | just (kvs , rem'') = just ((k , v) ∷ kvs , rem'')
  ... | nothing            = nothing
  continueObject _ _ _ _ = nothing

  parseObjectEntries : ℕ → List JSONToken → Maybe (List (String × JSONValue) × List JSONToken)
  parseObjectEntries zero _ = nothing
  parseObjectEntries (suc fuel) [] = nothing
  parseObjectEntries (suc fuel) (rbraceT ∷ rest) = just ([] , rest)
  parseObjectEntries (suc fuel) (stringT k ∷ colonT ∷ rest) with parseValue fuel rest
  ... | just (v , rem) = continueObject fuel k v rem
  ... | nothing        = nothing
  parseObjectEntries (suc fuel) _ = nothing



------------------------------------------------------------------------
-- Top-level JSON Parser
------------------------------------------------------------------------

parseJSON : List Char → Maybe JSONValue
parseJSON cs with tokenize cs
... | nothing   = nothing
... | just toks with parseValue (suc (length toks)) toks
...   | just (v , []) = just v
...   | _             = nothing
