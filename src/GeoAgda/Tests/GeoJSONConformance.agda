{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.GeoJSONConformance where

open import Data.List using ([]; _∷_)
open import Data.String as String using (String; toList)
open import Data.Integer using (+_; -[1+_])
import Data.Sign as Sign
open import Data.Fin.Patterns using (1F; 2F; 5F)
open import Data.Maybe using (just; nothing)
open import Data.Unit using (tt)
open import Relation.Nullary.Decidable using (yes; toWitness)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Data.Product using (_,_; ∃)

open import Data.JSON.AST
open import Data.JSON.Conformance
open import Data.JSON.RoundTrip using (parseJSON)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Extraction using (extractFeatureCollection)
open import GeoAgda.Model.GeoJSON.Schema
open import GeoAgda.Model.GeoJSON.Conformance
open import GeoAgda.Model.GeoJSON.Validate
open import GeoAgda.Tests.Fixtures using (pointGeoJSON)

------------------------------------------------------------------------
-- 1. Position Conformance & Proof Shortcut Test
------------------------------------------------------------------------

posJson : JSON
posJson = arrayⱼ
  ( numberⱼ (jsonNumber Sign.- 0 (1F ∷ 2F ∷ []) (+_ 0))
  ∷ numberⱼ (jsonNumber Sign.+ 51 (5F ∷ []) (+_ 0))
  ∷ []
  )

-- Decidable check returns constructive proof
testPosDec : ∃ (λ p → checkPosition posJson ≡ yes p)
testPosDec = _ , refl

-- Total extraction using the proof certificate
testPosShortcut : extractPositionFromEvidence (toWitness {a? = checkPosition posJson} tt)
                  ≡ pos (jsonNumber Sign.- 0 (1F ∷ 2F ∷ []) (+_ 0)) (jsonNumber Sign.+ 51 (5F ∷ []) (+_ 0))
testPosShortcut = refl

------------------------------------------------------------------------
-- 2. Geometry Conformance & Proof Shortcut Test
------------------------------------------------------------------------

pointGeomJson : JSON
pointGeomJson = objectFromList
  ( ("type" , stringⱼ "Point")
  ∷ ("coordinates" , posJson)
  ∷ []
  )

testGeomDec : ∃ (λ gEv → checkGeometry pointGeomJson ≡ yes gEv)
testGeomDec = _ , refl

testGeomShortcut : extractGeometryFromEvidence (toWitness {a? = checkGeometry pointGeomJson} tt)
                   ≡ pointG (pos (jsonNumber Sign.- 0 (1F ∷ 2F ∷ []) (+_ 0)) (jsonNumber Sign.+ 51 (5F ∷ []) (+_ 0)))
testGeomShortcut = refl

------------------------------------------------------------------------
-- 3. FeatureCollection Conformance & End-to-End Validation
------------------------------------------------------------------------

parsedPointFC : JSON
parsedPointFC with parseJSON (toList pointGeoJSON)
... | just v = v
... | nothing = nullⱼ

testFCDec : ∃ (λ fcEv → checkFeatureCollection parsedPointFC ≡ yes fcEv)
testFCDec = _ , refl

testValidateAndExtract : ∃ (λ fc → validateAndExtract parsedPointFC ≡ just fc)
testValidateAndExtract = _ , refl

-- Coherence test: validateAndExtract yields exactly the same result as extractFeatureCollection
testExtractionCoherence : validateAndExtract parsedPointFC ≡ extractFeatureCollection parsedPointFC
testExtractionCoherence = refl

------------------------------------------------------------------------
-- 4. Every geometry kind, the bbox, and the general coherence theorem
------------------------------------------------------------------------

multiGeoJSON : String
multiGeoJSON = "{\"type\":\"FeatureCollection\",\"bbox\":[0,0,3,3],\"features\":[{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"MultiPolygon\",\"coordinates\":[[[[0,0],[1,0],[1,1],[0,0]]],[[[2,2],[3,2],[3,3],[2,2]]]]}},{\"type\":\"Feature\",\"geometry\":{\"type\":\"MultiPoint\",\"coordinates\":[[0,0],[1,1]]}},{\"type\":\"Feature\",\"geometry\":{\"type\":\"MultiLineString\",\"coordinates\":[[[0,0],[1,1]],[[2,2],[3,3]]]}}]}"

parsedMultiFC : JSON
parsedMultiFC with parseJSON (toList multiGeoJSON)
... | just v = v
... | nothing = nullⱼ

testMultiFCDec : ∃ (λ fcEv → checkFeatureCollection parsedMultiFC ≡ yes fcEv)
testMultiFCDec = _ , refl

-- the verified path keeps the bbox and all geometry kinds
testMultiValidate : ∃ (λ fc → validateAndExtract parsedMultiFC ≡ just fc)
testMultiValidate = _ , refl

-- for every JSON value, not just the fixtures
testCoherenceGeneral : ∀ v → validateAndExtract v ≡ extractFeatureCollection v
testCoherenceGeneral = validateAndExtract-correct

-- a malformed collection is rejected by both
testRejected : extractFeatureCollection nullⱼ ≡ nothing
testRejected = refl
