{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone8 where

open import Level using (0ℓ)
open import Data.List using (List; []; _∷_)
open import Data.String as String using (String; toList)
open import Data.Integer using (+_; -[1+_])
import Data.Sign as Sign
open import Data.Fin.Patterns using (1F; 2F; 5F)
open import Data.Maybe using (Maybe; just; nothing)
open import Data.Unit using (tt)
open import Relation.Nullary.Decidable using (yes; no; toWitness)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Data.Product using (_×_; _,_; ∃)

open import Data.JSON.AST
open import Data.JSON.Conformance
open import GeoAgda.Parsing.JSON.Parser using (parseJSON)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Extraction using (extractPosition; extractGeometry; extractFeatureCollection)
open import GeoAgda.Model.GeoJSON.Conformance
open import GeoAgda.Tests.Fixtures using (pointGeoJSON; polygonGeoJSON; naturalEarthGeoJSON)

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
