{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Composing a map from several GeoJSON sources.
--
-- A `Layer` names a source file and says how to turn each of its features
-- into a feature of the composite (or drop it).  A `Group` is a few layers
-- whose results are post-processed together.  A recipe is a list of groups,
-- drawn in order, bottom first.  Reading files is left to the caller
-- (`exe/Earth.agda`), so the recipe stays pure.
module GeoAgda.Compose where

open import Data.Bool using (Bool; true; false; if_then_else_)
open import Data.List as List using (List; []; _∷_; map; concat; length)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Nat using (ℕ; _<ᵇ_)
open import Data.Product using (_,_)
open import Data.String using (String; _++_)
open import Data.String.Properties using (_==_)
open import Data.Sign using (Sign)
open import Data.Integer using (+_)
open import Function using (_∘_)

open import Data.JSON.AST using (JSON; jsonNumber; numberⱼ; stringⱼ)
open import GeoAgda.Model.Exact using (fromExactPt)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.Path using (pathRings)
open import GeoAgda.Rendering.SVG.Centroid using (positionsBBoxScaled; bboxCenter; geometryCentroid)
import Data.Sign as Sign

------------------------------------------------------------------------
-- Layers, groups, recipes
------------------------------------------------------------------------

record Layer : Set where
  constructor layerAt
  field
    path      : String                  -- relative to the data directory, or to the working directory
    inDataDir : Bool                    -- which of the two
    convert   : Feature → Maybe Feature -- `nothing` drops the feature

-- A layer from a file of the Natural Earth data directory.
layer : String → (Feature → Maybe Feature) → Layer
layer p c = layerAt p true c

-- A layer from any other file.
fileLayer : String → (Feature → Maybe Feature) → Layer
fileLayer p c = layerAt p false c

-- Where a layer is read from, given the data directory.
layerFile : String → Layer → String
layerFile dir l = if Layer.inDataDir l then dir ++ "/" ++ Layer.path l else Layer.path l

record Group : Set where
  constructor group
  field
    layers : List Layer
    finish : List Feature → List Feature

-- A group without post-processing.
simpleGroup : Layer → Group
simpleGroup l = group (l ∷ []) (λ fs → fs)

Recipe : Set
Recipe = List Group

catMaybes : ∀ {A : Set} → List (Maybe A) → List A
catMaybes []             = []
catMaybes (nothing ∷ xs) = catMaybes xs
catMaybes (just x ∷ xs)  = x ∷ catMaybes xs

applyLayer : Layer → FeatureCollection → List Feature
applyLayer l (featureCollection fs _) = catMaybes (map (Layer.convert l) fs)

-- Keep the first feature for each key; features without a key are kept.
dedupeBy : (Feature → Maybe String) → List Feature → List Feature
dedupeBy key = go []
  where
    seen : String → List String → Bool
    seen k []       = false
    seen k (x ∷ xs) = if k == x then true else seen k xs

    go : List String → List Feature → List Feature
    go _ [] = []
    go ks (f ∷ fs) with key f
    ... | nothing = f ∷ go ks fs
    ... | just k  = if seen k ks then go ks fs else f ∷ go (k ∷ ks) fs

------------------------------------------------------------------------
-- Building properties
------------------------------------------------------------------------

strP : String → JSON
strP = stringⱼ

natP : ℕ → JSON
natP n = numberⱼ (jsonNumber Sign.+ n [] (+ 0))

------------------------------------------------------------------------
-- Label anchors
------------------------------------------------------------------------

private
  rings : Geometry → List (List Position)
  rings (pointG _)             = []
  rings (multiPointG ps)       = ps ∷ []
  rings (lineStringG ps)       = ps ∷ []
  rings (multiLineStringG ls)  = ls
  rings (polygonG rs)          = rs
  rings (multiPolygonG ps)     = concat ps
  rings (geometryCollectionG _) = []
  rings (pathG p)              = map (map fromExactPt) (pathRings p)

  longest : List (List Position) → Maybe (List Position)
  longest []        = nothing
  longest (r ∷ rs) with longest rs
  ... | nothing = just r
  ... | just r′ = if length r′ <ᵇ length r then just r else just r′

-- Centre of the bounding box of the geometry's longest ring or line: for a
-- country or region this is the mainland rather than the average of all its
-- islands.
labelPoint : Geometry → Maybe Position
labelPoint (pointG p) = just p
labelPoint g@(geometryCollectionG _) = geometryCentroid g
labelPoint g = longest (rings g) >>= positionsBBoxScaled >>= (just ∘ bboxCenter)
