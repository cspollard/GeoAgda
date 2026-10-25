{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Composition helpers: text clean-up, vertex thinning, label anchors.
module GeoAgda.Tests.Compose where

open import Data.List using ([]; _∷_; length)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Nat using (ℕ)
open import Data.String using (String; toList; _++_)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Data.JSON.RoundTrip using (parseJSON)
open import GeoAgda
open import GeoAgda.Compose
open import GeoAgda.Compose.Text
open import GeoAgda.Compose.Options
open import Data.Sum using (inj₂; inj₁)
open import Data.Bool using (true; false)
open import GeoAgda.Model.GeoJSON.Simplify

------------------------------------------------------------------------
-- Text
------------------------------------------------------------------------

testFold : asciiFold "Pen\237nsula Ib\233rica, Kj\248len, Hawai\8216i" ≡ "Peninsula Iberica, Kjolen, Hawaii"
testFold = refl

testUpper : upper "Caucasus Mts." ≡ "CAUCASUS MTS."
testUpper = refl

testTitle : title "GREAT plains, rocky MTS." ≡ "Great Plains, Rocky Mts."
testTitle = refl

------------------------------------------------------------------------
-- Thinning
------------------------------------------------------------------------

geometryOf : String → Maybe Geometry
geometryOf s = parseJSON (toList s) >>= extractGeometry

vertices : Geometry → ℕ
vertices (polygonG (r ∷ _)) = length r
vertices (lineStringG r)    = length r
vertices _                  = 0

square : String
square = "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[2,0],[2,0],[2,2],[0,2],[0,0]]]}"

-- the repeated and the collinear vertices go; 5 remain (closing vertex included)
testThin : Maybe.map vertices (geometryOf square >>= simplifyGeometry 100 0) ≡ just 5
testThin = refl

-- rounding to 2 decimals merges vertices closer than 0.005°
testRound : Maybe.map vertices
              (geometryOf "{\"type\":\"LineString\",\"coordinates\":[[0.001,0],[0.002,0],[1,1]]}"
                >>= simplifyGeometry 100 0) ≡ just 2
testRound = refl

-- radial thinning keeps vertices ≥ r apart, and the last vertex
testRadial : Maybe.map vertices
               (geometryOf "{\"type\":\"LineString\",\"coordinates\":[[0,0],[0.1,0.5],[0.2,1],[0.3,1.5],[5,5]]}"
                 >>= simplifyGeometry 100 20000) ≡ just 2
testRadial = refl

-- a ring that collapses is dropped
testDegenerate : (geometryOf "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[0.001,0],[0,0.001],[0,0]]]}"
                    >>= simplifyGeometry 100 0) ≡ nothing
testDegenerate = refl

------------------------------------------------------------------------
-- Labels
------------------------------------------------------------------------

render : Maybe Position → Maybe String
render (just (pos x y)) = just (renderJSONNumber x ++ "," ++ renderJSONNumber y)
render nothing          = nothing

-- the centre of the longest ring, not of the whole multipolygon
testLabel : render (geometryOf "{\"type\":\"MultiPolygon\",\"coordinates\":[[[[0,0],[4,0],[4,2],[0,2],[0,0]]],[[[10,10],[11,10],[10,10]]]]}"
                      >>= labelPoint) ≡ just "2.00,1.00"
testLabel = refl

------------------------------------------------------------------------
-- Earth options
------------------------------------------------------------------------

testDegrees : parseDegrees "0.01" ≡ just 100
testDegrees = refl

testDegreesWhole : parseDegrees "3" ≡ just 30000
testDegreesWhole = refl

testDegreesTooFine : parseDegrees "0.00001" ≡ nothing
testDegreesTooFine = refl

testDefaults : parseArgs [] ≡ inj₂ defaultInvocation
testDefaults = refl

testFlags : parseArgs ("--land=areas" ∷ "--borders" ∷ "--thin=0" ∷ "dir" ∷ "o.svg" ∷ [])
  ≡ inj₂ (invocation (options areas true false 100 0) "dir" "o.svg")
testFlags = refl

testNoSimplify : parseArgs ("--precision=0" ∷ []) ≡ inj₂ (invocation (options elevation false false 0 3000) "natural-earth-geojson" "earth.svg")
testNoSimplify = refl

testBadFlag : parseArgs ("--nope" ∷ []) ≡ inj₁ "unknown option --nope"
testBadFlag = refl
