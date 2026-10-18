{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone8 where

open import Level using (0ℓ)
open import Data.List.Base using (List; []; _∷_)
open import Data.String.Base as String using (String; toList)
open import Data.Integer.Base using (+_; -[1+_])
open import Data.Sign.Base using (+; -)
open import Data.Maybe.Base using (Maybe; just; nothing)
open import Relation.Nullary.Decidable using (yes; no)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Data.Product.Base using (_×_; _,_; ∃)

open import GeoAgda.Data.JSON.AST
open import GeoAgda.Data.JSON.Conformance
open import GeoAgda.Parsing.JSON.Parser using (parseJSON)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Extraction using (extractPosition; extractGeometry; extractFeatureCollection)
open import GeoAgda.Model.GeoJSON.Conformance
open import GeoAgda.Tests.Fixtures using (pointGeoJSON; polygonGeoJSON; naturalEarthGeoJSON)

------------------------------------------------------------------------
-- 1. Position Conformance & Proof Shortcut Test
------------------------------------------------------------------------

posJson : JSON
posJson = arrayFromList
  ( number (jsonNumber - 0 (1 ∷ 2 ∷ []) (+ 0))
  ∷ number (jsonNumber + 51 (5 ∷ []) (+ 0))
  ∷ []
  )

-- Decidable check returns constructive proof
testPosDec : ∃ (λ p → checkPosition posJson ≡ yes p)
testPosDec = _ , refl

-- Total extraction using the proof certificate
testPosShortcut : ∃ (λ p → extractPositionFromEvidence p ≡ pos (jsonNumber - 0 (1 ∷ 2 ∷ []) (+ 0)) (jsonNumber + 51 (5 ∷ []) (+ 0)))
testPosShortcut with checkPosition posJson
... | yes p = p , refl

------------------------------------------------------------------------
-- 2. Geometry Conformance & Proof Shortcut Test
------------------------------------------------------------------------

pointGeomJson : JSON
pointGeomJson = objectFromKVs
  ( ("type" , string "Point")
  ∷ ("coordinates" , posJson)
  ∷ []
  )

testGeomDec : ∃ (λ gEv → checkGeometry pointGeomJson ≡ yes gEv)
testGeomDec = _ , refl

testGeomShortcut : ∃ (λ gEv → extractGeometryFromEvidence gEv ≡ pointG (pos (jsonNumber - 0 (1 ∷ 2 ∷ []) (+ 0)) (jsonNumber + 51 (5 ∷ []) (+ 0))))
testGeomShortcut with checkGeometry pointGeomJson
... | yes gEv = gEv , refl

------------------------------------------------------------------------
-- 3. FeatureCollection Conformance & End-to-End Validation
------------------------------------------------------------------------

parsedPointFC : JSON
parsedPointFC with parseJSON (toList pointGeoJSON)
... | just v = v
... | nothing = null

testFCDec : ∃ (λ fcEv → checkFeatureCollection parsedPointFC ≡ yes fcEv)
testFCDec = _ , refl

testValidateAndExtract : ∃ (λ fc → validateAndExtract parsedPointFC ≡ just fc)
testValidateAndExtract = _ , refl

-- Coherence test: validateAndExtract yields exactly the same result as extractFeatureCollection
testExtractionCoherence : validateAndExtract parsedPointFC ≡ extractFeatureCollection parsedPointFC
testExtractionCoherence = refl
