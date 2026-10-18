{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Data.JSON.Print where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Char.Base using (Char)
open import Data.Char.Properties using (_≟_)
open import Data.String.Base as String using (String; toList; fromList)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.Integer.Base using (ℤ; +_; -[1+_])
open import Data.Sign.Base using (Sign; +; -)
open import Data.Fin.Base using (Fin; zero; suc)
open import Data.List.Base as List using (List; []; _∷_; _++_; concat; map; length)
open import Data.Product.Base using (_×_; _,_)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_; _$_)
open import Relation.Nullary.Decidable using (yes; no)

open import GeoAgda.Data.JSON.AST
open import GeoAgda.Parsing.Invertible.Number public
  using (printSign; printNat; printFraction; printExponent; printNumber)

------------------------------------------------------------------------
-- String Escaping & Formatting
------------------------------------------------------------------------

-- Escape special JSON string characters using decidable equality
escapeString : List Char → List Char
escapeString [] = []
escapeString (c ∷ cs) with c ≟ '"' | c ≟ '\\' | c ≟ '\n' | c ≟ '\r' | c ≟ '\t'
... | yes _ | _     | _     | _     | _     = '\\' ∷ '"'  ∷ escapeString cs
... | no  _ | yes _ | _     | _     | _     = '\\' ∷ '\\' ∷ escapeString cs
... | no  _ | no  _ | yes _ | _     | _     = '\\' ∷ 'n'  ∷ escapeString cs
... | no  _ | no  _ | no  _ | yes _ | _     = '\\' ∷ 'r'  ∷ escapeString cs
... | no  _ | no  _ | no  _ | no  _ | yes _ = '\\' ∷ 't'  ∷ escapeString cs
... | no  _ | no  _ | no  _ | no  _ | no  _ = c ∷ escapeString cs

printStringLiteral : String → List Char
printStringLiteral s = '"' ∷ escapeString (toList s) ++ ('"' ∷ [])

------------------------------------------------------------------------
-- JSON Pretty-Printing
------------------------------------------------------------------------

mutual
  -- Pretty print a closed JSON value to a List Char
  printJSON : JSONValue → List Char
  printJSON (pure tt)           = 'n' ∷ 'u' ∷ 'l' ∷ 'l' ∷ []
  printJSON (bool true)         = 't' ∷ 'r' ∷ 'u' ∷ 'e' ∷ []
  printJSON (bool false)        = 'f' ∷ 'a' ∷ 'l' ∷ 's' ∷ 'e' ∷ []
  printJSON (number n)          = printNumber n
  printJSON (string s)          = printStringLiteral s
  printJSON (arrayFromList xs)  = '[' ∷ printArrayBody xs
  printJSON (objectFromKVs kvs) = '{' ∷ printObjectBody kvs

  printArrayBody : List JSONValue → List Char
  printArrayBody []             = ']' ∷ []
  printArrayBody (v ∷ [])       = printJSON v ++ (']' ∷ [])
  printArrayBody (v ∷ v₂ ∷ vs)  = printJSON v ++ (',' ∷ printArrayBody (v₂ ∷ vs))

  printObjectBody : List (String × JSONValue) → List Char
  printObjectBody []                    = '}' ∷ []
  printObjectBody ((k , v) ∷ [])        = printStringLiteral k ++ (':' ∷ printJSON v ++ ('}' ∷ []))
  printObjectBody ((k , v) ∷ kv₂ ∷ kvs) = printStringLiteral k ++ (':' ∷ printJSON v ++ (',' ∷ printObjectBody (kv₂ ∷ kvs)))

-- Render to standard Agda String
renderJSON : JSONValue → String
renderJSON = fromList ∘ printJSON
