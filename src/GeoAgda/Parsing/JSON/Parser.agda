{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.JSON.Parser where

open import Level using (0ℓ)
open import Data.Bool using (Bool; true; false)
open import Data.Char using (Char)
open import Data.String as String using (String)
open import Data.Nat as ℕ using (ℕ; zero; suc)
open import Data.List as List using (List; []; _∷_; length)
open import Data.Product using (_×_; _,_; map₁)
open import Data.Maybe as Maybe using (Maybe; just; nothing; map)
open import Data.Unit using (⊤; tt)
open import Function using (_∘_; _$_)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Data.JSON.AST
  using (JSON; nullⱼ; boolⱼ; numberⱼ; stringⱼ; arrayⱼ; objectFromList)
open import GeoAgda.Parsing.JSON.Lexer
  using (JSONToken; lbraceT; rbraceT; lbracketT; rbracketT; colonT; commaT; nullT; boolT; numberT; stringT; tokenize)

------------------------------------------------------------------------
-- Mutual Recursive-Descent Parser
------------------------------------------------------------------------

mutual
  parseValue : ℕ → List JSONToken → Maybe (JSON × List JSONToken)
  parseValue zero _ = nothing
  parseValue (suc fuel) (nullT ∷ rest)      = just (nullⱼ , rest)
  parseValue (suc fuel) (boolT b ∷ rest)    = just (boolⱼ b , rest)
  parseValue (suc fuel) (numberT n ∷ rest)  = just (numberⱼ n , rest)
  parseValue (suc fuel) (stringT s ∷ rest)  = just (stringⱼ s , rest)
  parseValue (suc fuel) (lbracketT ∷ rest)  =
    map (map₁ arrayⱼ) (parseArrayElements fuel rest)
  parseValue (suc fuel) (lbraceT ∷ rest)    =
    map (map₁ objectFromList) (parseObjectEntries fuel rest)
  parseValue (suc fuel) _                   = nothing

  continueArray : ℕ → JSON → List JSONToken → Maybe (List JSON × List JSONToken)
  continueArray fuel v (rbracketT ∷ rest) = just (v ∷ [] , rest)
  continueArray fuel v (commaT ∷ rest)    =
    map (map₁ (v ∷_)) (parseArrayElements fuel rest)
  continueArray _ _ _ = nothing

  parseArrayElements : ℕ → List JSONToken → Maybe (List JSON × List JSONToken)
  parseArrayElements zero _ = nothing
  parseArrayElements (suc fuel) [] = nothing
  parseArrayElements (suc fuel) (rbracketT ∷ rest) = just ([] , rest)
  parseArrayElements (suc fuel) toks with parseValue fuel toks
  ... | just (v , rem) = continueArray fuel v rem
  ... | nothing        = nothing

  continueObject : ℕ → String → JSON → List JSONToken → Maybe (List (String × JSON) × List JSONToken)
  continueObject fuel k v (rbraceT ∷ rem') = just ((k , v) ∷ [] , rem')
  continueObject fuel k v (commaT ∷ rem')  =
    map (map₁ ((k , v) ∷_)) (parseObjectEntries fuel rem')
  continueObject _ _ _ _ = nothing

  parseObjectEntries : ℕ → List JSONToken → Maybe (List (String × JSON) × List JSONToken)
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

parseJSON : List Char → Maybe JSON
parseJSON cs with tokenize cs
... | nothing   = nothing
... | just toks with parseValue (suc (length toks)) toks
...   | just (v , []) = just v
...   | _             = nothing
