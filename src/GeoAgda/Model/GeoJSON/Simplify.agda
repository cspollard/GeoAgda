{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Rounding coordinates and thinning vertices.  `simplifyGeometry g r`
--
--   * rounds every coordinate to the nearest multiple of `g` (units of 10⁻⁴°;
--     g = 100 is 2 decimals),
--   * removes repeated and exactly collinear consecutive vertices,
--   * if `r > 0`, keeps a vertex only when it is at least `r` away from the
--     previously kept one (radial-distance thinning: vertices stay on the
--     original outline, so it does not stair-step like a coarse grid;
--     r = 3000 is 0.3° and thins the 10m bathymetry ~10×),
--   * drops rings and lines that degenerate (rings keep their closing vertex).
module GeoAgda.Model.GeoJSON.Simplify where

open import Data.Bool using (Bool; true; false; if_then_else_; _∧_)
open import Data.Integer as ℤ using (ℤ; +_; -[1+_]; _+_; _-_; _*_; ∣_∣)
open import Data.List as List using (List; []; _∷_; reverse; length; map)
open import Data.Maybe as Maybe using (Maybe; just; nothing)
open import Data.Nat as ℕ using (ℕ; suc; NonZero; _/_; _≡ᵇ_; _≤ᵇ_) renaming (_*_ to _*ℕ_; _+_ to _+ℕ_)
open import Data.Product using (_×_; _,_)

open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Scaled using (jsonNumberToScaledℤ; scaledℤToJSONNumber)

Pt : Set
Pt = ℤ × ℤ

------------------------------------------------------------------------
-- Snapping
------------------------------------------------------------------------

-- Round to the nearest multiple of `g` (halves away from zero).
snap : (g : ℕ) .{{_ : NonZero g}} → ℤ → ℤ
snap g (+ n)    = + (((n +ℕ g / 2) / g) *ℕ g)
snap g -[1+ n ] = ℤ.- (+ (((suc n +ℕ g / 2) / g) *ℕ g))

private
  eqℤ : ℤ → ℤ → Bool
  eqℤ (+ m)    (+ n)    = m ≡ᵇ n
  eqℤ -[1+ m ] -[1+ n ] = m ≡ᵇ n
  eqℤ _        _        = false

  eqPt : Pt → Pt → Bool
  eqPt (x , y) (x′ , y′) = eqℤ x x′ ∧ eqℤ y y′

  -- (b - a) × (c - b) = 0
  collinear : Pt → Pt → Pt → Bool
  collinear (ax , ay) (bx , by) (cx , cy) =
    eqℤ ((bx - ax) * (cy - by)) ((by - ay) * (cx - bx))

  -- squared distance < r²
  close : ℕ → Pt → Pt → Bool
  close r (x , y) (x′ , y′) =
    let dx = ∣ x - x′ ∣
        dy = ∣ y - y′ ∣
    in (dx *ℕ dx +ℕ dy *ℕ dy) ℕ.<ᵇ (r *ℕ r)

toPt : Position → Pt
toPt (pos lon lat) = jsonNumberToScaledℤ lon , jsonNumberToScaledℤ lat

fromPt : Pt → Position
fromPt (x , y) = pos (scaledℤToJSONNumber x) (scaledℤToJSONNumber y)

------------------------------------------------------------------------
-- Lines and rings
------------------------------------------------------------------------

-- Remove repeated vertices and collapse collinear runs; `acc` holds the
-- kept vertices, most recent first.
thin : List Pt → List Pt → List Pt
thin acc []       = reverse acc
thin acc (p ∷ ps) with acc
... | []                = thin (p ∷ []) ps
... | a ∷ []            = thin (if eqPt a p then acc else p ∷ acc) ps
... | b ∷ a ∷ rest      =
  if eqPt b p then thin acc ps
  else if collinear a b p then thin (p ∷ a ∷ rest) ps
  else thin (p ∷ acc) ps

-- Keep a vertex only if it is ≥ r from the last kept one; the first and the
-- last vertex always stay (so closed rings stay closed).
radial : ℕ → List Pt → List Pt
radial r []       = []
radial r (p ∷ ps) = go (p ∷ []) ps
  where
    not-singleton : List Pt → Bool
    not-singleton []      = false
    not-singleton (_ ∷ _) = true

    go : List Pt → List Pt → List Pt
    go acc []                  = reverse acc
    go [] (q ∷ qs)             = go (q ∷ []) qs
    go (k ∷ acc) (q ∷ [])      =
      if close r k q ∧ not-singleton acc then reverse (q ∷ acc) else reverse (q ∷ k ∷ acc)
    go (k ∷ acc) (q ∷ qs)      =
      if close r k q then go (k ∷ acc) qs else go (q ∷ k ∷ acc) qs

snapLine : (g r : ℕ) .{{_ : NonZero g}} → List Position → List Pt
snapLine g r ps =
  let pts = thin [] (map (λ q → let (x , y) = toPt q in snap g x , snap g y) ps)
  in if r ≡ᵇ 0 then pts else radial r pts

-- A line needs 2 vertices, a closed ring 4.
line : (g r : ℕ) .{{_ : NonZero g}} → List Position → Maybe (List Position)
line g r ps with snapLine g r ps
... | pts = if 2 ≤ᵇ length pts then just (map fromPt pts) else nothing

ring : (g r : ℕ) .{{_ : NonZero g}} → List Position → Maybe (List Position)
ring g r ps with snapLine g r ps
... | pts = if 4 ≤ᵇ length pts then just (map fromPt pts) else nothing

------------------------------------------------------------------------
-- Geometries
------------------------------------------------------------------------

private
  catMaybes : ∀ {A : Set} → List (Maybe A) → List A
  catMaybes []             = []
  catMaybes (nothing ∷ xs) = catMaybes xs
  catMaybes (just x ∷ xs)  = x ∷ catMaybes xs

  -- A polygon is its outer ring plus holes; it needs a valid outer ring.
  polygonRings : (g r : ℕ) .{{_ : NonZero g}} → List (List Position) → Maybe (List (List Position))
  polygonRings g r []         = nothing
  polygonRings g r (o ∷ holes) with ring g r o
  ... | nothing = nothing
  ... | just o′ = just (o′ ∷ catMaybes (map (ring g r) holes))

  nonEmpty : ∀ {A : Set} {B : Set} → (List A → B) → List A → Maybe B
  nonEmpty f []       = nothing
  nonEmpty f xs@(_ ∷ _) = just (f xs)

snapPosition : (g : ℕ) .{{_ : NonZero g}} → Position → Position
snapPosition g p = let (x , y) = toPt p in fromPt (snap g x , snap g y)

mutual
  simplifyGeometry : (g r : ℕ) .{{_ : NonZero g}} → Geometry → Maybe Geometry
  simplifyGeometry g r (pointG p)             = just (pointG (snapPosition g p))
  simplifyGeometry g r (multiPointG ps)       = nonEmpty multiPointG (map (snapPosition g) ps)
  simplifyGeometry g r (lineStringG ps)       = Maybe.map lineStringG (line g r ps)
  simplifyGeometry g r (multiLineStringG ls)  = nonEmpty multiLineStringG (catMaybes (map (line g r) ls))
  simplifyGeometry g r (polygonG rs)          = Maybe.map polygonG (polygonRings g r rs)
  simplifyGeometry g r (multiPolygonG ps)     = nonEmpty multiPolygonG (catMaybes (map (polygonRings g r) ps))
  simplifyGeometry g r (geometryCollectionG gs) = nonEmpty geometryCollectionG (simplifyGeometries g r gs)
  simplifyGeometry g r (pathG p)              = just (pathG p)   -- already reduced

  simplifyGeometries : (g r : ℕ) .{{_ : NonZero g}} → List Geometry → List Geometry
  simplifyGeometries g r []        = []
  simplifyGeometries g r (x ∷ xs) with simplifyGeometry g r x
  ... | nothing = simplifyGeometries g r xs
  ... | just y  = y ∷ simplifyGeometries g r xs
