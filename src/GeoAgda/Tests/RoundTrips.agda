{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.RoundTrips where

open import Data.List using ([]; _∷_; _++_)
open import Data.String as String using (String; toList)
open import Data.Integer using (+_)
import Data.Sign as Sign
open import Data.Fin.Patterns using (1F; 2F; 5F)
open import Data.Maybe using (Maybe; just; nothing)
import Data.Maybe
open import Function.Bundles using (LeftInverse; RightInverse)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Data.Product using (_×_; _,_; ∃)
open import Data.Unit using (tt)
open import Data.Vec using () renaming (_∷_ to _∷ᵛ_; [] to []ᵛ)

open import Data.JSON.AST
open import Data.JSON.Print using (printJSON)
open import Data.JSON.RoundTrip using (parseJSON)
open import Data.JSON.Number using (jsonNumber)
open import Data.JSON.RoundTrip using (jsonStage; parseJSON-printJSON)
open import Data.JSON.Equality using (_≈ⱼ_)

open import Data.XML.AST
open import Data.XML.Sanitize using (element; textElement)
open import Data.XML.Print using (printXML; renderXML)
open import Data.XML.RoundTrip using (xmlStage; parseXML; parseXML-printXML)
open import Data.XML.Equality using (_≈ₓ_)
open import Data.XML.Escape using (lexBody; escapeText; escapeValue; lexBody-escapeText; lexBody-escapeValue)
open import Data.SVG

open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Tests.SVGRendering using (renderedMapDoc)

------------------------------------------------------------------------
-- 1. JSON Structural Inversion Tests
------------------------------------------------------------------------

-- Test number round-trip
testNumVal : JSON
testNumVal = numberⱼ (jsonNumber Sign.- 42 (1F ∷ 2F ∷ 5F ∷ []) (+_ 0))

testNumRoundTrip : parseJSON (printJSON testNumVal) ≡ just testNumVal
testNumRoundTrip = refl

-- Test array round-trip
testArrVal : JSON
testArrVal = arrayⱼ (nullⱼ ∷ trueⱼ ∷ falseⱼ ∷ testNumVal ∷ [])

testArrRoundTrip : parseJSON (printJSON testArrVal) ≡ just testArrVal
testArrRoundTrip = refl

-- Test object round-trip
testObjVal : JSON
testObjVal = objectFromList (("active" , trueⱼ) ∷ ("count" , testNumVal) ∷ [])

testObjRoundTrip : parseJSON (printJSON testObjVal) ≡ just testObjVal
testObjRoundTrip = refl

------------------------------------------------------------------------------------------------------------------------------------------
-- 2. XML & SVG Printing Tests
------------------------------------------------------------------------

-- (The universal round trip is in section 3.)

testRectDoc : XMLDoc
testRectDoc = rect "0" "0" "800" "400" (("fill" , "#ffffff") ∷ [])

_ : renderXML testRectDoc ≡ "<rect x=\"0\" y=\"0\" width=\"800\" height=\"400\" fill=\"#ffffff\" />"
_ = refl

testPolyDoc : XMLDoc
testPolyDoc = polygon "-25,-67 -13,-67" (("stroke" , "#000000") ∷ [])

_ : renderXML testPolyDoc ≡ "<polygon points=\"-25,-67 -13,-67\" stroke=\"#000000\" />"
_ = refl

-- Text is escaped; mixed content keeps its text slots in order.
_ : renderXML (textElement "title" [] "a<b & c") ≡ "<title>a&lt;b &amp; c</title>"
_ = refl

_ : renderXML (node (toList "p") [] (toList "x " ∷ᵛ toList " y" ∷ᵛ []ᵛ) (λ _ → leaf (toList "b") [] (toList "z"))
                {tt} {tt} {tt})
    ≡ "<p>x <b>z</b> y</p>"
_ = refl

-- Attribute values escape quotes and whitespace that parsers would normalise.
_ : renderXML (element "a" (("k" , "\"\n") ∷ []) []) ≡ "<a k=\"&quot;&#10;\" />"
_ = refl

-- Runtime data is repaired rather than rejected: duplicate attribute names
-- collapse (last wins), bad name characters become `_`, and NUL becomes U+FFFD.
_ : renderXML (element "g h" (("id" , "1") ∷ ("id" , "2") ∷ []) []) ≡ "<g_h id=\"2\" />"
_ = refl

_ : renderXML (textElement "t" [] "\0") ≡ "<t>\xFFFD</t>"
_ = refl

-- Decoding: predefined entities, numeric references (decimal and hex), and
-- the terminator is left in the rest.
_ : lexBody '<' (toList "a&amp;b&apos;&#65;&#x42;<c") ≡ just (toList "a&b'AB" , toList "<c")
_ = refl

-- Unknown entities, bad numeric references and NUL are rejected.
_ : lexBody '<' (toList "&nope;<") ≡ nothing
_ = refl

_ : lexBody '<' (toList "&#0;<") ≡ nothing
_ = refl

_ : lexBody '"' (toList "unterminated") ≡ nothing
_ = refl

-- Escaping then decoding is the identity (the general statements are
-- `lexBody-escapeText` and `lexBody-escapeValue`).
testEscapeText : ∀ cs rest → lexBody '<' (escapeText cs ++ '<' ∷ rest) ≡ just (cs , '<' ∷ rest)
testEscapeText = lexBody-escapeText

testEscapeValue : ∀ cs rest → lexBody '"' (escapeValue cs ++ '"' ∷ rest) ≡ just (cs , '"' ∷ rest)
testEscapeValue = lexBody-escapeValue

------------------------------------------------------------------------
-- 3. Universal Round-Trip, Retraction & Standard Library LeftInverse
------------------------------------------------------------------------


-- Verify universal JSON round-trip for ANY JSON (up to bisimilarity)
testUniversalRoundTrip : ∀ (v : JSON) → ∃ λ v′ → parseJSON (printJSON v) ≡ just v′ × v′ ≈ⱼ v
testUniversalRoundTrip = parseJSON-printJSON

-- Verify the total parser as a standard-library RightInverse
testUniversalRetraction : ∀ (v : JSON) →
  RightInverse.from jsonStage (RightInverse.to jsonStage v) ≈ⱼ v
testUniversalRetraction v = RightInverse.inverseʳ jsonStage refl

-- Verify universal XML round-trip for ANY document (up to bisimilarity)
testUniversalXMLRoundTrip : ∀ (v : XMLDoc) → ∃ λ v′ → parseXML (printXML v) ≡ just v′ × v′ ≈ₓ v
testUniversalXMLRoundTrip = parseXML-printXML

testUniversalXMLRetraction : ∀ (v : XMLDoc) →
  RightInverse.from xmlStage (RightInverse.to xmlStage v) ≈ₓ v
testUniversalXMLRetraction v = RightInverse.inverseʳ xmlStage refl

-- Concrete: parsing then printing a printed document gives it back (functions
-- in the AST rule out `≡` on documents themselves).
reprint : String → Maybe String
reprint s = Data.Maybe.map (λ d → renderXML d) (parseXML (toList s))

_ : reprint "<p>x <b>z</b> y</p>" ≡ just "<p>x <b>z</b> y</p>"
_ = refl

_ : reprint "<a k=\"&quot;&#10;\" />" ≡ just "<a k=\"&quot;&#10;\" />"
_ = refl

_ : reprint "<a><b></a>" ≡ nothing
_ = refl

-- The rendered map (`GeoAgda.Tests.SVGRendering`) parses back to a document that
-- prints the same.
_ : reprint (renderXML renderedMapDoc) ≡ just (renderXML renderedMapDoc)
_ = refl
