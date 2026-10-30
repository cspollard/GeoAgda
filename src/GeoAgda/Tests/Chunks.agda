{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- The chunks of a printed document concatenate to `printXML` (`Data.XML.Chunks`).
module GeoAgda.Tests.Chunks where

open import Data.List using (List; []; _∷_; concat)
open import Data.Product using (_,_)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Data.SVG using (svg; g; path)
open import Data.XML.AST using (XMLDoc)
open import Data.XML.Chunks using (xmlCharChunks)
open import Data.XML.Print using (printXML)
open import Data.XML.Sanitize using (textElement)

doc : XMLDoc
doc = svg (("viewBox" , "0 0 4 2") ∷ [])
        ( path "M 0 0 L 1 1 Z" (("fill" , "red") ∷ [])
        ∷ g (("id" , "a&b") ∷ []) (textElement "title" [] "x < y" ∷ path "M 1 1" [] ∷ [])
        ∷ [])

emptyDoc : XMLDoc
emptyDoc = svg [] []

testChunks : concat (xmlCharChunks doc) ≡ printXML doc
testChunks = refl

testEmpty : concat (xmlCharChunks emptyDoc) ≡ printXML emptyDoc
testEmpty = refl
