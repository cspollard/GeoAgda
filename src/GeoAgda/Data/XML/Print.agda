{-# OPTIONS --safe --cubical-compatible #-}

module GeoAgda.Data.XML.Print where

open import Level using (0ℓ)
open import Data.Char.Base using (Char)
open import Data.String.Base as String using (String; toList; fromList)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.List.Base as List using (List; []; _∷_; _++_; concat; map)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Unit.Base using (⊤; tt)
open import Data.Fin.Base using (Fin; zero; suc)
open import Data.Container.Core using (⟦_⟧)
open import Data.Container.FreeMonad using (foldr)
open import Function.Base using (_∘_; _$_)

open import GeoAgda.Data.XML.AST

------------------------------------------------------------------------
-- XML Catamorphism
------------------------------------------------------------------------

-- General fold / catamorphism over the XML free monad
foldXML : ∀ {X P : Set} → (X → P) → (⟦ XMLContainer ⟧ P → P) → XML X → P
foldXML algP algI = foldr algP algI

------------------------------------------------------------------------
-- Helpers: Attribute & Text Escaping
------------------------------------------------------------------------

open import GeoAgda.Container.Combinators using (tabulateFin)


-- Escape XML special characters in text content
escapeCharText : Char → List Char
escapeCharText '<' = '&' ∷ 'l' ∷ 't' ∷ ';' ∷ []
escapeCharText '>' = '&' ∷ 'g' ∷ 't' ∷ ';' ∷ []
escapeCharText '&' = '&' ∷ 'a' ∷ 'm' ∷ 'p' ∷ ';' ∷ []
escapeCharText c   = c ∷ []

escapeText : List Char → List Char
escapeText cs = concat (map escapeCharText cs)

-- Escape XML special characters in attribute values
escapeCharAttr : Char → List Char
escapeCharAttr '"' = '&' ∷ 'q' ∷ 'u' ∷ 'o' ∷ 't' ∷ ';' ∷ []
escapeCharAttr '<' = '&' ∷ 'l' ∷ 't' ∷ ';' ∷ []
escapeCharAttr '&' = '&' ∷ 'a' ∷ 'm' ∷ 'p' ∷ ';' ∷ []
escapeCharAttr c   = c ∷ []

escapeAttr : List Char → List Char
escapeAttr cs = concat (map escapeCharAttr cs)

-- Format a single attribute: ` key="val"`
printAttribute : Attribute → List Char
printAttribute (k , v) =
  ' ' ∷ toList k ++ ('=' ∷ '"' ∷ escapeAttr (toList v) ++ ('"' ∷ []))

printAttributes : Attributes → List Char
printAttributes attrs = concat (map printAttribute attrs)

------------------------------------------------------------------------
-- XML Serialization Algebra
------------------------------------------------------------------------

xmlPrintAlgebra : ⟦ XMLContainer ⟧ (List Char) → List Char
xmlPrintAlgebra (textₛ content , _) = escapeText (toList content)
xmlPrintAlgebra (elementₛ tag attrs zero , _) =
  '<' ∷ toList tag ++ printAttributes attrs ++ (' ' ∷ '/' ∷ '>' ∷ [])
xmlPrintAlgebra (elementₛ tag attrs (suc n) , rec) =
  ('<' ∷ toList tag ++ printAttributes attrs ++ ('>' ∷ [])) ++
  concat (tabulateFin (suc n) rec) ++
  ('<' ∷ '/' ∷ toList tag ++ ('>' ∷ []))

-- Serialize XML document to List Char
printXML : XMLDoc → List Char
printXML = foldXML (λ _ → []) xmlPrintAlgebra

-- Render XML document to String
renderXML : XMLDoc → String
renderXML = fromList ∘ printXML
