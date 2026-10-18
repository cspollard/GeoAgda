{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Data.XML.Print where

open import Data.Char.Base using (Char)
open import Data.Char.Properties using (_≟_)
open import Data.String.Base as String using (String; toList; fromList)
open import Data.List.Base as List using (List; []; _∷_; _++_)
open import Data.Product.Base using (_×_; _,_)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_)
open import Relation.Nullary.Decidable using (yes; no)

open import GeoAgda.Data.XML.AST

------------------------------------------------------------------------
-- Helpers: Tag Name, Attribute, & Text Escaping
------------------------------------------------------------------------

escapeName : List Char → List Char
escapeName [] = []
escapeName (c ∷ cs) with c ≟ '\\' | c ≟ ' ' | c ≟ '\t' | c ≟ '\n' | c ≟ '\r' | c ≟ '>' | c ≟ '/' | c ≟ '=' | c ≟ '<' | c ≟ '!'
... | yes _ | _     | _     | _     | _     | _     | _     | _     | _     | _     = '\\' ∷ '\\' ∷ escapeName cs
... | no  _ | yes _ | _     | _     | _     | _     | _     | _     | _     | _     = '\\' ∷ 's'  ∷ escapeName cs
... | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     | _     | _     = '\\' ∷ 't'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     | _     = '\\' ∷ 'n'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     = '\\' ∷ 'r'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     = '\\' ∷ 'g'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     = '\\' ∷ 'f'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     = '\\' ∷ 'e'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     = '\\' ∷ 'l'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ = '\\' ∷ 'b'  ∷ escapeName cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ = c ∷ escapeName cs

printName : String → List Char
printName s with toList s
... | []     = '\\' ∷ '0' ∷ []
... | c ∷ cs = escapeName (c ∷ cs)

escapeAttr : List Char → List Char
escapeAttr [] = []
escapeAttr (c ∷ cs) with c ≟ '\\' | c ≟ '"' | c ≟ '<' | c ≟ '>' | c ≟ '&'
... | yes _ | _     | _     | _     | _     = '\\' ∷ '\\' ∷ escapeAttr cs
... | no  _ | yes _ | _     | _     | _     = '\\' ∷ '"'  ∷ escapeAttr cs
... | no  _ | no  _ | yes _ | _     | _     = '\\' ∷ 'l'  ∷ escapeAttr cs
... | no  _ | no  _ | no  _ | yes _ | _     = '\\' ∷ 'g'  ∷ escapeAttr cs
... | no  _ | no  _ | no  _ | no  _ | yes _ = '\\' ∷ 'a'  ∷ escapeAttr cs
... | no  _ | no  _ | no  _ | no  _ | no  _ = c ∷ escapeAttr cs

-- Format a single attribute: ` key="val"`
printAttribute : Attribute → List Char
printAttribute (k , v) =
  ' ' ∷ printName k ++ ('=' ∷ '"' ∷ escapeAttr (toList v) ++ ('"' ∷ []))

printAttributes : Attributes → List Char
printAttributes []       = []
printAttributes (a ∷ as) = printAttribute a ++ printAttributes as

escapeText : List Char → List Char
escapeText [] = []
escapeText (c ∷ cs) with c ≟ '\\' | c ≟ '<' | c ≟ '>' | c ≟ '&' | c ≟ ' ' | c ≟ '\t' | c ≟ '\n' | c ≟ '\r'
... | yes _ | _     | _     | _     | _     | _     | _     | _     = '\\' ∷ '\\' ∷ escapeText cs
... | no  _ | yes _ | _     | _     | _     | _     | _     | _     = '\\' ∷ 'l'  ∷ escapeText cs
... | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     = '\\' ∷ 'g'  ∷ escapeText cs
... | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     = '\\' ∷ 'a'  ∷ escapeText cs
... | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     = '\\' ∷ 's'  ∷ escapeText cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     = '\\' ∷ 't'  ∷ escapeText cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     = '\\' ∷ 'n'  ∷ escapeText cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ = '\\' ∷ 'r'  ∷ escapeText cs
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ = c ∷ escapeText cs

printTextContent : String → List Char
printTextContent s = escapeText (toList s) ++ ('\\' ∷ 'e' ∷ [])

------------------------------------------------------------------------
-- XML Serialization
------------------------------------------------------------------------

mutual
  printXML : XMLDoc → List Char
  printXML (pure tt) = '<' ∷ '!' ∷ '>' ∷ []
  printXML (text s)  = printTextContent s
  printXML (elementList tag attrs []) =
    '<' ∷ printName tag ++ printAttributes attrs ++ (' ' ∷ '/' ∷ '>' ∷ [])
  printXML (elementList tag attrs (c ∷ cs)) =
    '<' ∷ printName tag ++ printAttributes attrs ++ ('>' ∷ printXMLChildren tag (c ∷ cs))

  printXMLChildren : String → List XMLDoc → List Char
  printXMLChildren tag []       = '<' ∷ '/' ∷ printName tag ++ ('>' ∷ [])
  printXMLChildren tag (c ∷ cs) = printXML c ++ printXMLChildren tag cs

-- Render XML document to String
renderXML : XMLDoc → String
renderXML = fromList ∘ printXML
