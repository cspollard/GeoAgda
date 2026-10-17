{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.JSON.Lexer where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false; if_then_else_)
open import Data.Char.Base using (Char)

open import Data.Char.Properties using (_≟_)
open import Data.String.Base as String using (String; fromList; toList)
open import Data.Nat.Base as ℕ using (ℕ; zero; suc; _*_) renaming (_+_ to _+ℕ_)
open import Data.Fin.Base using (Fin; zero; suc; toℕ)
open import Data.Integer.Base as ℤ using (ℤ; +_; -[1+_]; 0ℤ)
open import Data.Sign.Base as Sign using (Sign; +; -)
open import Data.List.Base as List using (List; []; _∷_; _++_; reverse)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_; _$_)
open import Relation.Nullary.Decidable using (yes; no)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda.Data.JSON.AST using (JSONNumber; jsonNumber)
open import GeoAgda.Parsing.Invertible.Char using (parseDigit; printDigit)
open import GeoAgda.Parsing.Invertible.Number using (digitsToNatAcc; digitsToNat; parseDigitsLoop)

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

isWhitespace : Char → Bool
isWhitespace ' '  = true
isWhitespace '\t' = true
isWhitespace '\n' = true
isWhitespace '\r' = true
isWhitespace _    = false

stripLeadingWhitespace : List Char → List Char
stripLeadingWhitespace [] = []
stripLeadingWhitespace (c ∷ cs) with isWhitespace c
... | true  = stripLeadingWhitespace cs
... | false = c ∷ cs

------------------------------------------------------------------------
-- String Literal Lexing
------------------------------------------------------------------------

lexStringChars : List Char → Maybe (List Char × List Char)
lexStringChars [] = nothing
lexStringChars ('"' ∷ cs) = just ([] , cs)
lexStringChars ('\\' ∷ '"'  ∷ cs) with lexStringChars cs
... | nothing         = nothing
... | just (acc , rem) = just ('"' ∷ acc , rem)
lexStringChars ('\\' ∷ '\\' ∷ cs) with lexStringChars cs
... | nothing         = nothing
... | just (acc , rem) = just ('\\' ∷ acc , rem)
lexStringChars ('\\' ∷ 'n'  ∷ cs) with lexStringChars cs
... | nothing         = nothing
... | just (acc , rem) = just ('\n' ∷ acc , rem)
lexStringChars ('\\' ∷ 't'  ∷ cs) with lexStringChars cs
... | nothing         = nothing
... | just (acc , rem) = just ('\t' ∷ acc , rem)
lexStringChars ('\\' ∷ 'r'  ∷ cs) with lexStringChars cs
... | nothing         = nothing
... | just (acc , rem) = just ('\r' ∷ acc , rem)
lexStringChars (c ∷ cs) with lexStringChars cs
... | nothing         = nothing
... | just (acc , rem) = just (c ∷ acc , rem)

------------------------------------------------------------------------
-- Number Lexing
------------------------------------------------------------------------

lexFraction : List Char → List (Fin 10) × List Char
lexFraction ('.' ∷ cs) = parseDigitsLoop cs
lexFraction cs         = ([] , cs)

lexExponent : List Char → ℤ × List Char
lexExponent ('e' ∷ '-' ∷ cs) with parseDigitsLoop cs
... | (ds , rest) = (-[1+ ℕ.pred (digitsToNat ds) ] , rest)
lexExponent ('e' ∷ '+' ∷ cs) with parseDigitsLoop cs
... | (ds , rest) = (+_ (digitsToNat ds) , rest)
lexExponent ('e' ∷ cs) with parseDigitsLoop cs
... | (ds , rest) = (+_ (digitsToNat ds) , rest)
lexExponent ('E' ∷ '-' ∷ cs) with parseDigitsLoop cs
... | (ds , rest) = (-[1+ ℕ.pred (digitsToNat ds) ] , rest)
lexExponent ('E' ∷ '+' ∷ cs) with parseDigitsLoop cs
... | (ds , rest) = (+_ (digitsToNat ds) , rest)
lexExponent ('E' ∷ cs) with parseDigitsLoop cs
... | (ds , rest) = (+_ (digitsToNat ds) , rest)
lexExponent cs = (0ℤ , cs)

lexNumber : Sign → List Char → Maybe (JSONNumber × List Char)
lexNumber s cs with parseDigitsLoop cs
... | ([] , _) = nothing
... | (d ∷ ds , rest₁) with lexFraction rest₁
...   | (frac , rest₂) with lexExponent rest₂
...     | (exp , rest₃) = just (jsonNumber s (digitsToNat (d ∷ ds)) frac exp , rest₃)

open import Data.Maybe.Base as Maybe using (Maybe; just; nothing; map)

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
