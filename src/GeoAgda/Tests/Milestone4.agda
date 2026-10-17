{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Milestone4 where

open import Data.List.Base using (List; []; _∷_)
open import Data.String.Base using (toList)
open import Data.Product.Base using (_,_)
open import Data.Sign.Base using (+; -)
open import Data.Integer.Base using (0ℤ)
open import Data.Maybe.Base using (just)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda

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
... | nothing = Data.Maybe.Base.nothing

_ : testExtractGeom ≡ just (pointG (pos (jsonNumber + 10 [] 0ℤ) (jsonNumber + 20 [] 0ℤ)))
_ = refl

-- Test 2: Feature Extraction
testExtractFeature : Maybe Feature
testExtractFeature with parseJSON sampleFeatureStr
... | just v  = extractFeature v
... | nothing = Data.Maybe.Base.nothing

_ : testExtractFeature ≡ just
  (feature Data.Maybe.Base.nothing
    (pointG (pos (jsonNumber + 10 [] 0ℤ) (jsonNumber + 20 [] 0ℤ)))
    (("name" , string "London") ∷ []))
_ = refl

-- Test 3: FeatureCollection Extraction
testExtractCollection : Maybe FeatureCollection
testExtractCollection with parseJSON sampleCollectionStr
... | just v  = extractFeatureCollection v
... | nothing = Data.Maybe.Base.nothing

_ : testExtractCollection ≡ just
  (featureCollection
    (feature Data.Maybe.Base.nothing
      (pointG (pos (jsonNumber + 10 [] 0ℤ) (jsonNumber + 20 [] 0ℤ)))
      (("name" , string "London") ∷ [])
    ∷ []))
_ = refl

