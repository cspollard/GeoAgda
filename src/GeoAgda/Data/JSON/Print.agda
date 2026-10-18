{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Data.JSON.Print where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Char.Base using (Char)
open import Data.Char.Properties using (_≟_)
open import Data.String.Base as String using (String; toList; fromList)
open import Data.String.Properties using () renaming (≡-decSetoid to stringDecSetoid)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.Integer.Base using (ℤ; +_; -[1+_])
open import Data.Sign.Base using (Sign; +; -)
open import Data.Fin.Base using (Fin; zero; suc)
open import Data.List.Base as List
  using (List; []; _∷_; _++_; concat; map; length; intercalate)
open import Data.Product.Base using (_×_; _,_)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_; _$_)
open import Relation.Nullary.Decidable using (yes; no)
open import Data.Container as C
open import Data.Empty

open import GeoAgda.Data.JSON.AST
open import GeoAgda.Data.JSON.ObjectC stringDecSetoid
open JSONCont
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

-- Pretty print a closed JSON value to a List Char
print⊤ : ⊤ → List Char
print⊤ _ = 'n' ∷ 'u' ∷ 'l' ∷ 'l' ∷ []

printPrim : (t : PrimJSONType) → (RetType t) → List Char
printPrim PrimJSONType.primstring = toList
printPrim PrimJSONType.primnumber = printNumber
printPrim PrimJSONType.primbool = toList ∘ show
  where open import Data.Bool.Show
printPrim PrimJSONType.primnull = print⊤

printJSON : JSON → List Char
printArrayBody : ⟦ ListC ⟧ (List Char) → List Char
printObjectBody : ⟦ StringObjectC ⟧ (List Char) → List Char

printArrayBody = intercalate (',' ∷  ' ' ∷ []) ∘ listCToList

printObjectBody = intercalate (',' ∷ ' ' ∷ []) ∘ List.map go ∘ objectToList
  where
    go : (String × List Char) → List Char
    go (k , x) = toList k ++ ':' ∷ ' ' ∷ x

printJSON = foldJSONM (λ ()) go
  where
    go : (t : JSONType) (x : ⟦ JSON→ t ⟧ (List Char)) → List Char
    go object x = '{' ∷ printObjectBody x ++ '}' ∷ []
    go array x  = '[' ∷ printArrayBody x ++ ']' ∷ []
    go (prim t) (x , _) = printPrim t x

-- Render to standard Agda String
renderJSON : JSON → String
renderJSON = fromList ∘ printJSON
