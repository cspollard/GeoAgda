{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Model.GeoJSON.Extraction where

open import Level using (0ℓ)
open import Data.String.Base as String using (String)
open import Data.String.Properties using (_≟_)
open import Data.List.Base as List using (List; []; _∷_; map)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe.Base as Maybe using (Maybe; just; nothing)
open import Function.Base using (_∘_; _$_)
open import Relation.Nullary.Decidable using (yes; no)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import GeoAgda.Data.JSON.AST using (JSONValue; JSONNumber)
open import GeoAgda.Data.JSON.Schema using (asArray; asObject; asString; asNumber; lookupField)
open import GeoAgda.Model.GeoJSON.Types

------------------------------------------------------------------------
-- Coordinate & Position Extraction
------------------------------------------------------------------------

mkPos : Maybe JSONNumber → Maybe JSONNumber → Maybe Position
mkPos (just lon) (just lat) = just (pos lon lat)
mkPos _          _          = nothing

-- Extract a single [longitude, latitude] pair
extractPosition : JSONValue → Maybe Position
extractPosition v with asArray v
... | just (lonV ∷ latV ∷ []) = mkPos (asNumber lonV) (asNumber latV)
... | _                       = nothing


-- Helper: Map extraction across a list, failing if any element fails
mapM : ∀ {A B : Set} → (A → Maybe B) → List A → Maybe (List B)
mapM _ []       = just []
mapM f (x ∷ xs) with f x
... | nothing  = nothing
... | just y   with mapM f xs
...   | nothing  = nothing
...   | just ys  = just (y ∷ ys)

-- Extract a line or ring of positions
extractPositions : JSONValue → Maybe (List Position)
extractPositions v with asArray v
... | nothing   = nothing
... | just arrs = mapM extractPosition arrs

-- Extract polygon rings: list of linear rings (outer + inner holes)
extractRings : JSONValue → Maybe (List (List Position))
extractRings v with asArray v
... | nothing   = nothing
... | just arrs = mapM extractPositions arrs

------------------------------------------------------------------------
-- Geometry Extraction
------------------------------------------------------------------------

extractGeometryFromObject : List (String × JSONValue) → Maybe Geometry
extractGeometryFromObject kvs with lookupField "type" kvs | lookupField "coordinates" kvs
... | just typeVal | just coordsVal with asString typeVal
...   | nothing       = nothing
...   | just typeName with typeName ≟ "Point"
...     | yes _ with extractPosition coordsVal
...       | just p  = just (pointG p)
...       | nothing = nothing
...     | no  _ with typeName ≟ "LineString"
...       | yes _ with extractPositions coordsVal
...         | just ps = just (lineStringG ps)
...         | nothing = nothing
...       | no  _ with typeName ≟ "Polygon"
...         | yes _ with extractRings coordsVal
...           | just rings = just (polygonG rings)
...           | nothing    = nothing
...         | no  _ = nothing

extractGeometryFromObject _ = nothing

extractGeometry : JSONValue → Maybe Geometry
extractGeometry v with asObject v
... | nothing  = nothing
... | just kvs = extractGeometryFromObject kvs

------------------------------------------------------------------------
-- Feature Extraction
------------------------------------------------------------------------

extractFeatureFromObject : List (String × JSONValue) → Maybe Feature
extractFeatureFromObject kvs with lookupField "type" kvs | lookupField "geometry" kvs
... | just typeVal | just geomVal with asString typeVal
...   | nothing       = nothing
...   | just typeName with typeName ≟ "Feature"
...     | no  _ = nothing
...     | yes _ with extractGeometry geomVal
...       | nothing   = nothing
...       | just geom =
          let idVal = lookupField "id" kvs >>= asString
              props = lookupField "properties" kvs >>= asObject
              finalProps = Maybe.fromMaybe [] props
          in just (feature idVal geom finalProps)
          where open import Data.Maybe.Base using (_>>=_)
extractFeatureFromObject _ = nothing

extractFeature : JSONValue → Maybe Feature
extractFeature v with asObject v
... | nothing  = nothing
... | just kvs = extractFeatureFromObject kvs

------------------------------------------------------------------------
-- FeatureCollection Extraction
------------------------------------------------------------------------

extractFeatureCollectionFromObject : List (String × JSONValue) → Maybe FeatureCollection
extractFeatureCollectionFromObject kvs with lookupField "type" kvs | lookupField "features" kvs
... | just typeVal | just featuresVal with asString typeVal
...   | nothing       = nothing
...   | just typeName with typeName ≟ "FeatureCollection"
...     | no  _ = nothing
...     | yes _ with asArray featuresVal
...       | nothing       = nothing
...       | just featArr  with mapM extractFeature featArr
...         | nothing     = nothing
...         | just feats  = just (featureCollection feats)
extractFeatureCollectionFromObject _ = nothing

extractFeatureCollection : JSONValue → Maybe FeatureCollection
extractFeatureCollection v with asObject v
... | nothing  = nothing
... | just kvs = extractFeatureCollectionFromObject kvs
