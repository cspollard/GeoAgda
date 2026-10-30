{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Tests.Path where

open import Data.List using (List; []; _∷_; map)
open import Data.Char using (Char)
open import Data.Fin.Patterns using (0F; 1F; 2F; 4F; 5F)
open import Data.Integer using (+_; -[1+_])
open import Data.Maybe using (just; nothing)
open import Data.Product using (_,_)
open import Data.Sign using (+; -)
open import Data.String using (toList)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Data.JSON.AST using (jsonNumber)
open import GeoAgda.Model.Exact
open import GeoAgda.Model.GeoJSON.Types using (pos; Position)
open import GeoAgda.Rendering.SVG.Path
open import GeoAgda.Rendering.SVG.PathData using (formatRingD)
open import GeoAgda.Rendering.SVG.Projection using (equirectangular)

-- 12.5 and -0.12 are exact
testExact₁ : toExact (jsonNumber + 12 (5F ∷ []) (+_ 0)) ≡ just (+_ 12500000000000000)
testExact₁ = refl

testExact₂ : toExact (jsonNumber - 0 (1F ∷ 2F ∷ []) (+_ 0)) ≡ just -[1+ 119999999999999 ]
testExact₂ = refl

-- an exponent is applied: 1.25e2 = 125
testExact₃ : toExact (jsonNumber + 1 (2F ∷ 5F ∷ []) (+_ 2)) ≡ just (+_ 125000000000000000)
testExact₃ = refl

-- digits beyond the 15th are rounded: 0.0000000000000005 → 1 unit, 0.0000000000000004 → 0
testRound₁ : toExact (jsonNumber + 0 (0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 5F ∷ []) (+_ 0)) ≡ just (+_ 1)
testRound₁ = refl

testRound₂ : toExact (jsonNumber + 0 (0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 4F ∷ []) (+_ 0)) ≡ just (+_ 0)
testRound₂ = refl

-- trailing zeros are absorbed
testZeros : toExact (jsonNumber + 12 (5F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ 0F ∷ []) (+_ 0))
            ≡ just (+_ 12500000000000000)
testZeros = refl

-- the way back trims trailing zeros
testBack : fromExact (+_ 12500000000000000) ≡ jsonNumber + 12 (5F ∷ []) (+_ 0)
testBack = refl

testBackNeg : fromExact -[1+ 119999999999999 ] ≡ jsonNumber - 0 (1F ∷ 2F ∷ []) (+_ 0)
testBackNeg = refl

-- A ring renders as `formatRingD` does
a b c : Pt
a = +_ 0 , +_ 0
b = +_ 10000000000000000 , +_ 0
c = +_ 10000000000000000 , +_ 5000000000000000

testRing : renderPath equirectangular (finish (ring (a ∷ b ∷ c ∷ a ∷ [])))
         ≡ formatRingD equirectangular (map fromExactPt (a ∷ b ∷ c ∷ a ∷ []))
testRing = refl

------------------------------------------------------------------------
-- `reduceGeometry` keeps the vertices `Simplify` keeps
------------------------------------------------------------------------

open import GeoAgda.Model.GeoJSON.Reduce using (reduceGeometry; exactGeometry)
open import GeoAgda.Model.GeoJSON.Simplify using (simplifyGeometry)
open import GeoAgda.Model.GeoJSON.Types using (Geometry; polygonG; multiPolygonG; pathG)
open import GeoAgda.Model.Path using (pathRings)
open import GeoAgda.Rendering.SVG.PathData using (formatPolygonD)
open import Data.Fin.Patterns using (3F; 4F)
open import Data.Maybe using (Maybe)
import Data.Maybe as Maybe

-- 0.00 0.00, 1.34 0.00, 2.34 0.00 (collinear), 2.34 1.50, 0.00 0.00 (closing): the middle vertex goes
sq : List Position
sq = pos (jsonNumber + 0 [] (+_ 0)) (jsonNumber + 0 [] (+_ 0))
   ∷ pos (jsonNumber + 1 (3F ∷ 4F ∷ []) (+_ 0)) (jsonNumber + 0 [] (+_ 0))
   ∷ pos (jsonNumber + 2 (3F ∷ 4F ∷ []) (+_ 0)) (jsonNumber + 0 [] (+_ 0))
   ∷ pos (jsonNumber + 2 (3F ∷ 4F ∷ []) (+_ 0)) (jsonNumber + 1 (5F ∷ []) (+_ 0))
   ∷ pos (jsonNumber + 0 [] (+_ 0)) (jsonNumber + 0 [] (+_ 0))
   ∷ []

ringsOf : Maybe Geometry → Maybe (List (List Pt))
ringsOf (just (pathG p)) = just (pathRings p)
ringsOf _                = nothing

-- the same vertices from the reduced polygon as from `Simplify`'s output (precision 0.01°, no thinning)
testReduce : ringsOf (reduceGeometry 100 0 (polygonG (sq ∷ [])))
           ≡ ringsOf (Maybe.map exactGeometry (simplifyGeometry 100 0 (polygonG (sq ∷ []))))
testReduce = refl

-- and the collinear middle vertex is gone
testReduceVertices : ringsOf (reduceGeometry 100 0 (polygonG (sq ∷ [])))
  ≡ just (((+_ 0 , +_ 0) ∷ (+_ 2340000000000000 , +_ 0) ∷ (+_ 2340000000000000 , +_ 1500000000000000) ∷ (+_ 0 , +_ 0) ∷ []) ∷ [])
testReduceVertices = refl

-- a ring that collapses is dropped, as in `Simplify`
testReduceDrop : reduceGeometry 100 0 (polygonG ((pos (jsonNumber + 0 [] (+_ 0)) (jsonNumber + 0 [] (+_ 0)) ∷ []) ∷ [])) ≡ nothing
testReduceDrop = refl
