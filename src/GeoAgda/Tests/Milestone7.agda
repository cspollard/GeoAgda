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

open import Data.JSON.AST
open import Data.JSON.Print using (printJSON)
open import GeoAgda.Parsing.JSON.Parser using (parseJSON)
open import Data.JSON.Number using (jsonNumber)
open import Data.JSON.RoundTrip using (jsonStage; parseJSON-printJSON)
open import Data.JSON.Equality using (_≈ⱼ_)

open import Data.XML.AST
open import Data.XML.Print using (printXML)
open import GeoAgda.Parsing.XML.Parser using (parseXMLChars)
open import GeoAgda.Parsing.XML.Soundness

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

------------------------------------------------------------------------
-- 2. XML & SVG Inversion Tests
------------------------------------------------------------------------

-- Test SVG rect round-trip
testRectDoc : XMLDoc
testRectDoc = rect "0" "0" "800" "400" (("fill" , "#ffffff") ∷ [])

testRectRoundTrip : parseXMLChars (printXML testRectDoc) ≡ just testRectDoc
testRectRoundTrip = refl

-- Test SVG polygon round-trip
testPolyDoc : XMLDoc
testPolyDoc = polygon "-25,-67 -13,-67 -13,-63 -25,-63" (("stroke" , "#000000") ∷ [])

testPolyRoundTrip : parseXMLChars (printXML testPolyDoc) ≡ just testPolyDoc
testPolyRoundTrip = refl

-- Test full rendered SVG map round-trip
renderedMap : XMLDoc
renderedMap = renderMapSVG defaultPolygonStyle testFeatureCollection

testMapRoundTrip : parseXMLChars (printXML renderedMap) ≡ just renderedMap
testMapRoundTrip = refl

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
