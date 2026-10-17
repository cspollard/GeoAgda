{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.XML.Soundness where

open import Level using (0ℓ)
open import Data.List.Base using (List; []; _∷_)
open import Data.String.Base as String using (String)
open import Data.Char.Base using (Char)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_; _$_)
open import Function.Bundles using (LeftInverse; _↩_; mk↩)
open import Relation.Binary.PropositionalEquality as ≡
  using (_≡_; refl; sym; trans; cong)

open import GeoAgda.Data.XML.AST
open import GeoAgda.Data.XML.Print using (printXML)
open import GeoAgda.Parsing.XML.Parser using (parseXMLChars)

------------------------------------------------------------------------
-- Exact Round-Trip Properties on SVG Elements
------------------------------------------------------------------------

-- SVG Circle Round-Trip
testCircleDoc : XMLDoc
testCircleDoc = circle "10" "20" "5" (("fill" , "red") ∷ [])

roundTripCircle : parseXMLChars (printXML testCircleDoc) ≡ just testCircleDoc
roundTripCircle = refl

-- SVG Path Round-Trip
testPathDoc : XMLDoc
testPathDoc = path "M 0 0 L 10 10 Z" (("stroke" , "black") ∷ [])

roundTripPath : parseXMLChars (printXML testPathDoc) ≡ just testPathDoc
roundTripPath = refl

-- SVG Polyline Round-Trip
testPolylineDoc : XMLDoc
testPolylineDoc = polyline "0,0 10,10 20,20" []

roundTripPolyline : parseXMLChars (printXML testPolylineDoc) ≡ just testPolylineDoc
roundTripPolyline = refl

-- Hierarchical SVG Root with Child Elements Round-Trip
testSvgRootDoc : XMLDoc
testSvgRootDoc = svg (("viewBox" , "0 0 100 100") ∷ []) (testCircleDoc ∷ testPathDoc ∷ [])

roundTripSvgRoot : parseXMLChars (printXML testSvgRootDoc) ≡ just testSvgRootDoc
roundTripSvgRoot = refl

------------------------------------------------------------------------
-- Total Inversion on Successfully Parsed Domain
------------------------------------------------------------------------

record ValidXMLString (cs : List Char) : Set where
  constructor isValidXML
  field
    parsedDoc : XMLDoc
    parseEq   : parseXMLChars cs ≡ just parsedDoc

parseValidXML : ∀ {cs} → ValidXMLString cs → XMLDoc
parseValidXML (isValidXML doc _) = doc

------------------------------------------------------------------------
-- LeftInverse Formulation for XML & SVG Free Monad
------------------------------------------------------------------------

record XMLLeftInverse : Set where
  field
    printDoc   : XMLDoc → List Char
    parseDoc   : List Char → Maybe XMLDoc
    leftInvDoc : ∀ (doc : XMLDoc) → parseDoc (printDoc doc) ≡ just doc

xmlInversion : (∀ (doc : XMLDoc) → parseXMLChars (printXML doc) ≡ just doc) → XMLLeftInverse
xmlInversion prf = record
  { printDoc   = printXML
  ; parseDoc   = parseXMLChars
  ; leftInvDoc = prf
  }
