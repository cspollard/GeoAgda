{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone7 where

open import Level using (0ℓ)
open import Data.List.Base using (List; []; _∷_)
open import Data.String.Base as String using (String; toList)
open import Data.Integer.Base using (+_; -[1+_])
open import Data.Sign.Base using (+; -)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Data.Product.Base using (_×_; _,_; ∃)

open import GeoAgda.Data.JSON.AST
open import GeoAgda.Data.JSON.Print using (printJSON)
open import GeoAgda.Parsing.JSON.Parser using (parseJSON)
open import GeoAgda.Parsing.JSON.Soundness

open import GeoAgda.Data.XML.AST
open import GeoAgda.Data.XML.Print using (printXML)
open import GeoAgda.Parsing.XML.Parser using (parseXMLChars)
open import GeoAgda.Parsing.XML.Soundness

open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Render using (renderMapSVG; defaultPolygonStyle)
open import GeoAgda.Tests.Milestone5 using (testFeatureCollection)

------------------------------------------------------------------------
-- 1. JSON Structural Inversion Tests
------------------------------------------------------------------------

-- Test number round-trip
testNumVal : JSONValue
testNumVal = number (jsonNumber - 42 (1 ∷ 2 ∷ 5 ∷ []) (+ 0))

testNumRoundTrip : parseJSON (printJSON testNumVal) ≡ just testNumVal
testNumRoundTrip = refl

-- Test array round-trip
testArrVal : JSONValue
testArrVal = arrayFromList (null ∷ trueⱼ ∷ falseⱼ ∷ testNumVal ∷ [])

testArrRoundTrip : parseJSON (printJSON testArrVal) ≡ just testArrVal
testArrRoundTrip = refl

-- Test object round-trip
testObjVal : JSONValue
testObjVal = objectFromKVs (("active" , trueⱼ) ∷ ("count" , testNumVal) ∷ [])

testObjRoundTrip : parseJSON (printJSON testObjVal) ≡ just testObjVal
testObjRoundTrip = refl

------------------------------------------------------------------------
-- 2. XML & SVG Free Monad Inversion Tests
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
-- 3. Standard Library LeftInverse Bundle Verification
------------------------------------------------------------------------

-- Verify XML retraction through parseXMLTotal
testXMLRetraction : parseXMLTotal (printXML renderedMap) ≡ renderedMap
testXMLRetraction = xmlRetraction renderedMap testMapRoundTrip

-- Verify JSON retraction through parseJSONTotal
testJSONRetraction : parseJSONTotal (printJSON testObjVal) ≡ testObjVal
testJSONRetraction = jsonRetraction testObjVal testObjRoundTrip

-- Verify base value LeftInverse instances from XML Soundness
_ : circleRetraction ≡ refl
_ = refl

_ : pathRetraction ≡ refl
_ = refl

-- Verify base value LeftInverse instances from JSON Soundness
_ : nullRetraction ≡ refl
_ = refl

_ : trueRetraction ≡ refl
_ = refl

_ : falseRetraction ≡ refl
_ = refl
