{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}



module GeoAgda.Tests.Milestone1 where

open import Data.List using ([]; _∷_)
open import Data.Product using (_,_)
open import Data.Sign using (+; -)
open import Data.Integer using (0ℤ)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda

------------------------------------------------------------------------
-- JSON Unit Test: Construct and serialize a Point fixture
------------------------------------------------------------------------

samplePointJSON : JSON
samplePointJSON = objectFromlist
  ( ("type" , string "Point")
  ∷ ("coordinates" , arrayFromList
      ( number (jsonNumber + 10 [] 0ℤ)
      ∷ number (jsonNumber + 20 [] 0ℤ)
      ∷ []
      ))
  ∷ []
  )

-- Compile-time propositional equality test for JSON printing
_ : renderJSON samplePointJSON ≡ "{\"type\":\"Point\",\"coordinates\":[10,20]}"
_ = refl

------------------------------------------------------------------------
-- SVG Unit Test: Construct and serialize an SVG canvas with circle
------------------------------------------------------------------------

sampleSVG : XMLDoc
sampleSVG = svg
  ( ("width" , "100") ∷ ("height" , "100") ∷ [] )
  ( circle "50" "50" "10" (("fill" , "red") ∷ []) ∷ [] )

-- Compile-time propositional equality test for SVG printing
_ : renderXML sampleSVG ≡ "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><circle cx=\"50\" cy=\"50\" r=\"10\" fill=\"red\" /></svg>"
_ = refl
