{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone7 where

open import Level using (0ℓ)
open import Data.List using (List; []; _∷_)
open import Data.String as String using (String; toList)
open import Data.Integer using (+_; -[1+_])
import Data.Sign as Sign
open import Data.Fin.Patterns using (1F; 2F; 5F)
open import Data.Maybe using (Maybe; just; nothing)
open import Function.Bundles using (LeftInverse; RightInverse)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Data.Product using (_×_; _,_; ∃)
open import Data.Unit using (tt)
open import Data.Vec using () renaming (_∷_ to _∷ᵛ_; [] to []ᵛ)

open import Data.JSON.AST
open import Data.JSON.Print using (printJSON)
open import GeoAgda.Parsing.JSON.Parser using (parseJSON)
open import Data.JSON.Number using (jsonNumber)
open import Data.JSON.RoundTrip using (jsonStage; parseJSON-printJSON)
open import Data.JSON.Equality using (_≈ⱼ_)

open import Data.XML.AST
open import Data.XML.Sanitize using (element; textElement)
open import Data.XML.Print using (printXML; renderXML)
open import Data.SVG

open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Render using (renderMapSVG; defaultPolygonStyle)
open import GeoAgda.Tests.Milestone5 using (testFeatureCollection)

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

-- (The XML parser and its round-trip theorem are still to be written, see
-- plans/XMLPlan.md; until then these check the printer.)

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

------------------------------------------------------------------------
-- 3. Universal Round-Trip, Retraction & Standard Library LeftInverse
------------------------------------------------------------------------

-- (The universal XML round-trip and retraction theorems are still to be
-- proved: `GeoAgda.Parsing.XML.Soundness` is a stub; see plans/JSONPlan.md.)

-- Verify universal JSON round-trip for ANY JSON (up to bisimilarity)
testUniversalRoundTrip : ∀ (v : JSON) → ∃ λ v′ → parseJSON (printJSON v) ≡ just v′ × v′ ≈ⱼ v
testUniversalRoundTrip = parseJSON-printJSON

-- Verify the total parser as a standard-library RightInverse
testUniversalRetraction : ∀ (v : JSON) →
  RightInverse.from jsonStage (RightInverse.to jsonStage v) ≈ⱼ v
testUniversalRetraction v = RightInverse.inverseʳ jsonStage refl
