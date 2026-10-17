{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}



module GeoAgda.Data.JSON.Print where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Char.Base using (Char)
open import Data.String.Base as String using (String; toList; fromList)
open import Data.Nat.Base using (ℕ; zero; suc)
import Data.Nat.Show as NatShow
open import Data.Integer.Base using (ℤ; +_; -[1+_])
import Data.Integer.Show as IntShow
open import Data.Sign.Base using (Sign; +; -)
open import Data.Fin.Base using (Fin; zero; suc)
open import Data.Digit using (showDigit)
open import Data.List.Base as List using (List; []; _∷_; _++_; concat; map; length)
open import Data.Product.Base using (_×_; _,_)
open import Data.Unit.Base using (⊤; tt)
open import Data.Container.Core using (⟦_⟧)
open import Data.Container.FreeMonad using (foldr)
open import Function.Base using (_∘_; _$_)

open import GeoAgda.Data.JSON.AST

------------------------------------------------------------------------
-- JSON Catamorphism
------------------------------------------------------------------------

-- General fold / catamorphism over the JSON free monad
foldJSON : ∀ {X P : Set} → (X → P) → (⟦ JSONContainer ⟧ P → P) → JSON X → P
foldJSON algP algI = foldr algP algI

------------------------------------------------------------------------
-- Helpers: List & Formatting Combinators
------------------------------------------------------------------------

open import GeoAgda.Container.Combinators using (tabulateFin; intersperseChar)


-- Escape special JSON string characters
escapeChar : Char → List Char
escapeChar '"'  = '\\' ∷ '"' ∷ []
escapeChar '\\' = '\\' ∷ '\\' ∷ []
escapeChar '\n' = '\\' ∷ 'n' ∷ []
escapeChar '\r' = '\\' ∷ 'r' ∷ []
escapeChar '\t' = '\\' ∷ 't' ∷ []
escapeChar c    = c ∷ []

escapeString : List Char → List Char
escapeString cs = concat (map escapeChar cs)

printStringLiteral : String → List Char
printStringLiteral s = '"' ∷ escapeString (toList s) ++ ('"' ∷ [])

------------------------------------------------------------------------
-- Number Formatting
------------------------------------------------------------------------

showFractionDigit : Fin 10 → Char
showFractionDigit d = showDigit d

printFraction : List (Fin 10) → List Char
printFraction []       = []
printFraction (d ∷ ds) = '.' ∷ map showFractionDigit (d ∷ ds)

printExponent : ℤ → List Char
printExponent (+_ zero) = []
printExponent e         = 'e' ∷ toList (IntShow.show e)


open import GeoAgda.Parsing.Invertible.Number using (printSign)


printNumber : JSONNumber → List Char
printNumber n =
  printSign (JSONNumber.sign n) ++
  toList (NatShow.show (JSONNumber.integral n)) ++
  printFraction (JSONNumber.fraction n) ++
  printExponent (JSONNumber.exponent n)

------------------------------------------------------------------------
-- Field & Object Formatting
------------------------------------------------------------------------

formatFields : (keys : List String) → (Fin (length keys) → List Char) → List (List Char)
formatFields []       _ = []
formatFields (k ∷ ks) f = (printStringLiteral k ++ (':' ∷ f zero)) ∷ formatFields ks (f ∘ suc)

------------------------------------------------------------------------
-- JSON Pretty-Printing Algebra
------------------------------------------------------------------------

jsonPrintAlgebra : ⟦ JSONContainer ⟧ (List Char) → List Char
jsonPrintAlgebra (nullₛ          , _)   = 'n' ∷ 'u' ∷ 'l' ∷ 'l' ∷ []
jsonPrintAlgebra (boolₛ true     , _)   = 't' ∷ 'r' ∷ 'u' ∷ 'e' ∷ []
jsonPrintAlgebra (boolₛ false    , _)   = 'f' ∷ 'a' ∷ 'l' ∷ 's' ∷ 'e' ∷ []
jsonPrintAlgebra (numberₛ n      , _)   = printNumber n
jsonPrintAlgebra (stringₛ s      , _)   = printStringLiteral s
jsonPrintAlgebra (arrayₛ n       , rec) = '[' ∷ intersperseChar ',' (tabulateFin n rec) ++ (']' ∷ [])
jsonPrintAlgebra (objectₛ keys   , rec) = '{' ∷ intersperseChar ',' (formatFields keys rec) ++ ('}' ∷ [])


-- Pretty print a closed JSON value to a List Char
printJSON : JSONValue → List Char
printJSON = foldJSON (λ _ → []) jsonPrintAlgebra

-- Render to standard Agda String
renderJSON : JSONValue → String
renderJSON = fromList ∘ printJSON
