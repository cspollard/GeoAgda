{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone4 where

open import Data.List using (List; []; _∷_)
open import Data.String using (toList)
open import Data.Product using (_,_)
open import Data.Sign using (+; -)
open import Data.Integer using (0ℤ)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda
open import Data.Maybe using (Maybe; just; nothing)

------------------------------------------------------------------------
-- Fixtures
------------------------------------------------------------------------

samplePointStr : List _
samplePointStr = toList "{ \"type\" : \"Point\" , \"coordinates\" : [ 10 , 20 ] }"

sampleFeatureStr : List _
sampleFeatureStr = toList "{ \"type\" : \"Feature\" , \"geometry\" : { \"type\" : \"Point\" , \"coordinates\" : [ 10 , 20 ] } , \"properties\" : { \"name\" : \"London\" } }"

sampleCollectionStr : List _
sampleCollectionStr = toList "{ \"type\" : \"FeatureCollection\" , \"features\" : [ { \"type\" : \"Feature\" , \"geometry\" : { \"type\" : \"Point\" , \"coordinates\" : [ 10 , 20 ] } , \"properties\" : { \"name\" : \"London\" } } ] }"

------------------------------------------------------------------------
-- Extraction Tests
------------------------------------------------------------------------

-- Test 1: Geometry Extraction
testExtractGeom : Maybe Geometry
testExtractGeom with parseJSON samplePointStr
... | just v  = extractGeometry v
... | nothing = Data.Maybe.nothing

_ : testExtractGeom ≡ just (pointG (pos (jsonNumber + 10 [] 0ℤ) (jsonNumber + 20 [] 0ℤ)))
_ = refl

-- Test 2: Feature Extraction
testExtractFeature : Maybe Feature
testExtractFeature with parseJSON sampleFeatureStr
... | just v  = extractFeature v
... | nothing = Data.Maybe.nothing

_ : testExtractFeature ≡ just
  (feature Data.Maybe.nothing
    (pointG (pos (jsonNumber + 10 [] 0ℤ) (jsonNumber + 20 [] 0ℤ)))
    (("name" , stringⱼ "London") ∷ []))
_ = refl

-- Test 3: FeatureCollection Extraction
testExtractCollection : Maybe FeatureCollection
testExtractCollection with parseJSON sampleCollectionStr
... | just v  = extractFeatureCollection v
... | nothing = Data.Maybe.nothing

_ : testExtractCollection ≡ just
  (featureCollection
    (feature Data.Maybe.nothing
      (pointG (pos (jsonNumber + 10 [] 0ℤ) (jsonNumber + 20 [] 0ℤ)))
      (("name" , stringⱼ "London") ∷ [])
    ∷ [])
    nothing)
_ = refl

