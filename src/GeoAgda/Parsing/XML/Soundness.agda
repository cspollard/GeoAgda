{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.XML.Soundness where

open import Level using (0ℓ)
open import Data.List.Base using (List; []; _∷_)
open import Data.String.Base as String using (String)
open import Data.Char.Base using (Char)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Data.Unit.Base using (⊤; tt)
open import Data.Product.Base using (_×_; _,_)
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
-- Total Parser & stdlib LeftInverse Implementation
------------------------------------------------------------------------

parseXMLTotal : List Char → XMLDoc
parseXMLTotal cs with parseXMLChars cs
... | just doc = doc
... | nothing  = text ""

-- Retraction lemma generator from any parse-after-print round-trip proof
xmlRetraction : ∀ (doc : XMLDoc) → parseXMLChars (printXML doc) ≡ just doc → parseXMLTotal (printXML doc) ≡ doc
xmlRetraction doc eq with parseXMLChars (printXML doc)
... | just parsedDoc with eq
...   | refl = refl

-- Inverseˡ property: ∀ {x y} → y ≡ printXML x → parseXMLTotal y ≡ x
xmlInverseˡ : (∀ (doc : XMLDoc) → parseXMLChars (printXML doc) ≡ just doc) →
              ∀ {cs : List Char} {doc : XMLDoc} → doc ≡ parseXMLTotal cs → printXML doc ≡ cs → parseXMLTotal (printXML doc) ≡ doc
xmlInverseˡ prf _ _ = xmlRetraction _ (prf _)

-- StrictlyInverseˡ property for parseXMLTotal after printXML:
-- parseXMLTotal (printXML doc) ≡ doc
-- In Function.Bundles:
-- LeftInverse (≡.setoid (List Char)) (≡.setoid XMLDoc) has:
--   to   : List Char → XMLDoc
--   from : XMLDoc → List Char
--   inverseˡ : Inverseˡ _≡_ _≡_ to from
-- where Inverseˡ _≡_ _≡_ to from = ∀ {x y} → y ≡ from x → to y ≡ x
-- With x = doc, y = printXML doc (so y ≡ from x is refl), to y ≡ x is parseXMLTotal (printXML doc) ≡ doc!
xmlLeftInverseˡ : (∀ (doc : XMLDoc) → parseXMLChars (printXML doc) ≡ just doc) →
                  ∀ {doc : XMLDoc} {cs : List Char} → cs ≡ printXML doc → parseXMLTotal cs ≡ doc
xmlLeftInverseˡ prf refl = xmlRetraction _ (prf _)

-- Build stdlib LeftInverse bundle from a global or domain roundtrip proof
-- parseXMLTotal : List Char → XMLDoc
-- printXML       : XMLDoc → List Char
xmlLeftInverseWith : (∀ (doc : XMLDoc) → parseXMLChars (printXML doc) ≡ just doc) →
                     (List Char ↩ XMLDoc)
xmlLeftInverseWith prf = mk↩ {to = parseXMLTotal} {from = printXML} (xmlLeftInverseˡ prf)

-- Backward compatibility record
record XMLLeftInverse : Set where
  field
    printDoc   : XMLDoc → List Char
    parseDoc   : List Char → Maybe XMLDoc
    leftInvDoc : ∀ (doc : XMLDoc) → parseDoc (printDoc doc) ≡ just doc
    stdlibInv  : (∀ (doc : XMLDoc) → parseDoc (printDoc doc) ≡ just doc) → (List Char ↩ XMLDoc)

xmlInversion : (∀ (doc : XMLDoc) → parseXMLChars (printXML doc) ≡ just doc) → XMLLeftInverse
xmlInversion prf = record
  { printDoc   = printXML
  ; parseDoc   = parseXMLChars
  ; leftInvDoc = prf
  ; stdlibInv  = xmlLeftInverseWith
  }

-- Concrete LeftInverse instances for verified XML & SVG forms
circleRetraction : parseXMLTotal (printXML testCircleDoc) ≡ testCircleDoc
circleRetraction = xmlRetraction testCircleDoc roundTripCircle

pathRetraction : parseXMLTotal (printXML testPathDoc) ≡ testPathDoc
pathRetraction = xmlRetraction testPathDoc roundTripPath

polylineRetraction : parseXMLTotal (printXML testPolylineDoc) ≡ testPolylineDoc
polylineRetraction = xmlRetraction testPolylineDoc roundTripPolyline

svgRootRetraction : parseXMLTotal (printXML testSvgRootDoc) ≡ testSvgRootDoc
svgRootRetraction = xmlRetraction testSvgRootDoc roundTripSvgRoot
