{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Polygons as paths: the retained form of area geometry (see plans/PathPlan.md).
--
--   * `reduceGeometry g r` does what `Simplify.simplifyGeometry g r` does (snapping,
--     removing repeated and collinear vertices, radial thinning) and converts the
--     surviving polygon rings to a `Path` of exact coordinates.  It *uses* `Simplify`'s
--     reduction, so the vertices kept are the same ones; only the representation changes.
--   * `exactGeometry` converts without reducing (`--precision=0`).
--
-- Other geometries are left as they are (reduced by `Simplify` for `reduceGeometry`).
module GeoAgda.Model.GeoJSON.Reduce where

open import Data.Bool using (if_then_else_)
open import Data.Integer as ℤ using (ℤ; +_)
open import Data.List using (List; []; _∷_; map; concat; length)
open import Data.Maybe as Maybe using (Maybe; just; nothing)
open import Data.Nat as ℕ using (ℕ; NonZero; _≤ᵇ_) renaming (_*_ to _*ℕ_)
open import Data.Product using (_,_)
import Data.Product as Product

open import GeoAgda.Model.Exact using (toExactPt)
open import GeoAgda.Model.GeoJSON.Simplify as Simplify using (snapLine; simplifyGeometry)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.Path

private
  -- `Simplify` works in units of 10⁻⁴°, a `Path` in units of 10⁻¹⁵°.
  up : Simplify.Pt → Pt
  up (x , y) = ℤ.+ 100000000000 ℤ.* x , ℤ.+ 100000000000 ℤ.* y

  catMaybes : ∀ {A : Set} → List (Maybe A) → List A
  catMaybes []             = []
  catMaybes (nothing ∷ xs) = catMaybes xs
  catMaybes (just x ∷ xs)  = x ∷ catMaybes xs

  -- A closed ring needs 4 vertices (as in `Simplify.ring`).
  reduceRing : (g r : ℕ) .{{_ : NonZero g}} → List Position → Maybe (List Pt)
  reduceRing g r ps with snapLine g r ps
  ... | pts = if 4 ≤ᵇ length pts then just (map up pts) else nothing

  -- A polygon is its outer ring plus holes; it needs a valid outer ring.
  reducePolygon : (g r : ℕ) .{{_ : NonZero g}} → List (List Position) → Maybe (List (List Pt))
  reducePolygon g r []         = nothing
  reducePolygon g r (o ∷ holes) with reduceRing g r o
  ... | nothing = nothing
  ... | just o′ = just (o′ ∷ catMaybes (map (reduceRing g r) holes))

  toPath : List (List Pt) → Geometry
  toPath rs = pathG (polygonP rs)

reduceGeometry : (g r : ℕ) .{{_ : NonZero g}} → Geometry → Maybe Geometry
reduceGeometry g r (polygonG rs)      = Maybe.map toPath (reducePolygon g r rs)
reduceGeometry g r (multiPolygonG ps) with catMaybes (map (reducePolygon g r) ps)
... | []         = nothing
... | rs@(_ ∷ _) = just (toPath (concat rs))
reduceGeometry g r geom                 = simplifyGeometry g r geom

------------------------------------------------------------------------
-- Without reduction
------------------------------------------------------------------------

private
  exactRing : List Position → Maybe (List Pt)
  exactRing []       = just []
  exactRing (p ∷ ps) with toExactPt p | exactRing ps
  ... | just q | just qs = just (q ∷ qs)
  ... | _      | _       = nothing

  exactRings : List (List Position) → Maybe (List (List Pt))
  exactRings []       = just []
  exactRings (r ∷ rs) with exactRing r | exactRings rs
  ... | just r′ | just rs′ = just (r′ ∷ rs′)
  ... | _       | _        = nothing

-- Polygons become paths; a polygon with a coordinate out of range (an exponent beyond ±64) stays as it was.
exactGeometry : Geometry → Geometry
exactGeometry geom@(polygonG rs) with exactRings rs
... | just rs′ = toPath rs′
... | nothing  = geom
exactGeometry geom@(multiPolygonG ps) with exactRings (concat ps)
... | just rs′ = toPath rs′
... | nothing  = geom
exactGeometry geom = geom
