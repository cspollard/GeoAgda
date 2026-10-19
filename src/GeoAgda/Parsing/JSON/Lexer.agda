{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.JSON.Lexer where

open import Level using (0ℓ)
open import Data.Bool using (Bool; true; false; if_then_else_)
open import Data.Char using (Char; isSpace)
open import Data.Char.Properties using (_≟_)
open import Data.String as String using (String; fromList; toList)
open import Data.Nat as ℕ using (ℕ; zero; suc; _*_) renaming (_+_ to _+ℕ_)
open import Data.Fin using (Fin; zero; suc; toℕ)
open import Data.Integer as ℤ using (ℤ; +_; -[1+_]; 0ℤ)
open import Data.Sign as Sign using (Sign; +; -)
open import Data.List as List using (List; []; _∷_; _++_; reverse)
open import Data.Product using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe as Maybe using (Maybe; just; nothing; map)
open import Data.Unit using (⊤; tt)
open import Function using (_∘_; _$_)
open import Relation.Nullary.Decidable using (yes; no)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda.Data.JSON.AST using (JSONNumber; jsonNumber)
open import GeoAgda.Parsing.Invertible.Char using (parseDigit; printDigit)
open import GeoAgda.Parsing.Invertible.Number public
  using (digitsToNatAcc; digitsToNat; parseDigitsLoop; lexFraction; lexExponent; lexNumber)

------------------------------------------------------------------------
-- JSON Tokens
------------------------------------------------------------------------

data JSONToken : Set where
  lbraceT   : JSONToken   -- {
  rbraceT   : JSONToken   -- }
  lbracketT : JSONToken   -- [
  rbracketT : JSONToken   -- ]
  colonT    : JSONToken   -- :
  commaT    : JSONToken   -- ,
  nullT     : JSONToken   -- null
  boolT     : Bool → JSONToken
  numberT   : JSONNumber → JSONToken
  stringT   : String → JSONToken

------------------------------------------------------------------------
-- Whitespace Handling
------------------------------------------------------------------------

stripLeadingWhitespace : List Char → List Char
stripLeadingWhitespace [] = []
stripLeadingWhitespace (c ∷ cs) with isSpace c
... | true  = stripLeadingWhitespace cs
... | false = c ∷ cs

------------------------------------------------------------------------
-- String Literal Lexing
------------------------------------------------------------------------

lexStringChars : List Char → Maybe (List Char × List Char)
lexStringChars [] = nothing
lexStringChars (c ∷ cs) with c ≟ '"'
... | yes _ = just ([] , cs)
... | no  _ with c ≟ '\\'
...   | no _ with lexStringChars cs
...     | nothing          = nothing
...     | just (acc , rem) = just (c ∷ acc , rem)
lexStringChars (c ∷ [])     | no _ | yes _ = nothing
lexStringChars (c ∷ d ∷ cs) | no _ | yes _ with d ≟ '"' | d ≟ '\\' | d ≟ 'n' | d ≟ 'r' | d ≟ 't'
... | yes _ | _     | _     | _     | _ with lexStringChars cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('"' ∷ acc , rem)
lexStringChars (c ∷ d ∷ cs) | no _ | yes _ | no _ | yes _ | _     | _     | _ with lexStringChars cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('\\' ∷ acc , rem)
lexStringChars (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | yes _ | _     | _ with lexStringChars cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('\n' ∷ acc , rem)
lexStringChars (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | no  _ | yes _ | _ with lexStringChars cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('\r' ∷ acc , rem)
lexStringChars (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | no  _ | no  _ | yes _ with lexStringChars cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('\t' ∷ acc , rem)
lexStringChars (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | no  _ | no  _ | no  _ = nothing

infixr 4 _<$>_
_<$>_ : ∀ {A B : Set} → (A → B) → Maybe A → Maybe B
f <$> m = Maybe.map f m

------------------------------------------------------------------------
-- Main Tokenizer Loop
------------------------------------------------------------------------

lexToken : List Char → Maybe (JSONToken × List Char)
lexToken ('{' ∷ rest) = just (lbraceT , rest)
lexToken ('}' ∷ rest) = just (rbraceT , rest)
lexToken ('[' ∷ rest) = just (lbracketT , rest)
lexToken (']' ∷ rest) = just (rbracketT , rest)
lexToken (':' ∷ rest) = just (colonT , rest)
lexToken (',' ∷ rest) = just (commaT , rest)
lexToken ('n' ∷ 'u' ∷ 'l' ∷ 'l' ∷ rest)  = just (nullT , rest)
lexToken ('t' ∷ 'r' ∷ 'u' ∷ 'e' ∷ rest)  = just (boolT true , rest)
lexToken ('f' ∷ 'a' ∷ 'l' ∷ 's' ∷ 'e' ∷ rest) = just (boolT false , rest)
lexToken ('"' ∷ rest) with lexStringChars rest
... | nothing                = nothing
... | just (strChars , rem)  = just (stringT (fromList strChars) , rem)
lexToken ('-' ∷ rest) with lexNumber - rest
... | nothing                = nothing
... | just (num , rem)       = just (numberT num , rem)
lexToken (c ∷ rest) with parseDigit c
... | nothing                = nothing
... | just _ with lexNumber + (c ∷ rest)
...   | nothing              = nothing
...   | just (num , rem)     = just (numberT num , rem)
lexToken [] = nothing

tokenizeLoop : ℕ → List Char → Maybe (List JSONToken)
tokenizeLoop zero _ = nothing
tokenizeLoop (suc fuel) cs with stripLeadingWhitespace cs
... | [] = just []
... | c ∷ rest with lexToken (c ∷ rest)
...   | nothing          = nothing
...   | just (tok , rem) = (tok ∷_) <$> tokenizeLoop fuel rem

tokenize : List Char → Maybe (List JSONToken)
tokenize cs = tokenizeLoop (suc (List.length cs)) cs
