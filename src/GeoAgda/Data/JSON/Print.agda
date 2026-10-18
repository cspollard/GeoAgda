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
open import Data.Container as C
open import Data.Empty

open import GeoAgda.Data.JSON.AST
open JSONCont using (PrimJSONType; RetType; JSONC; foldJSONM)
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

printJSONC : ⟦ JSONC ⟧ (List Char) → List Char
printJSONC = {!   !}
-- printJSONC ((JSONCont.object , snd₁) , snd) = {!   !}
-- printJSONC ((JSONCont.array , snd₁) , snd) = {!   !}
-- printJSONC ((JSONCont.prim t , x) , _) = printPrim t x

printJSON : JSON → List Char
printArrayBody : List JSON → List Char
printObjectBody : List (String × JSON) → List Char
printArrayBody []             = ']' ∷ []
printArrayBody (v ∷ [])       = printJSON v ++ (']' ∷ [])
printArrayBody (v ∷ v₂ ∷ vs)  = printJSON v ++ (',' ∷ printArrayBody (v₂ ∷ vs))

printObjectBody []                    = '}' ∷ []
printObjectBody ((k , v) ∷ [])        = printStringLiteral k ++ (':' ∷ printJSON v ++ ('}' ∷ []))
printObjectBody ((k , v) ∷ kv₂ ∷ kvs) = printStringLiteral k ++ (':' ∷ printJSON v ++ (',' ∷ printObjectBody (kv₂ ∷ kvs)))

printJSON = foldJSONM (λ ()) (λ t cs x → cs ++ printPrim t x) {!   !} {!   !}



-- -- Render to standard Agda String
-- renderJSON : JSON → String
-- renderJSON = fromList ∘ printJSON
