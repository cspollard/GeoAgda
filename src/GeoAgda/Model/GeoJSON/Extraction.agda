{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Partial extraction of the GeoJSON model from a parsed JSON value.
--
-- Every extractor is a chain of the total projections of
-- `Data.JSON.Schema` in the `Maybe` monad.  `GeoAgda.Model.GeoJSON.Conformance`
-- gives the declarative account of when extraction succeeds, and
-- `GeoAgda.Model.GeoJSON.Properties` proves the two agree.
module GeoAgda.Model.GeoJSON.Extraction where

open import Data.String as String using (String)
open import Data.String.Properties using (_≟_)
open import Data.List as List using (List; []; _∷_)
open import Data.Product using (_×_)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
import Data.Maybe.Effectful as Maybe
import Data.List.Effectful as ListE
open import Data.Unit using (⊤; tt)
open import Relation.Nullary.Decidable using (yes; no)

open import Data.JSON.AST using (JSON)
open import Data.JSON.Schema using (asArray; asObject; asString; asNumber; lookupField)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Schema

Object : Set
Object = List (String × JSON)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

-- Map extraction across a list, failing if any element fails
mapM : ∀ {A B : Set} → (A → Maybe B) → List A → Maybe (List B)
mapM = mapA
  where open ListE.TraversableA Maybe.applicative

guardEq : String → String → Maybe ⊤
guardEq s t with s ≟ t
... | yes _ = just tt
... | no  _ = nothing

-- Succeeds when the `type` member is the string `tag`.
hasType : String → Object → Maybe ⊤
hasType tag kvs =
  lookupField "type" kvs >>= λ tv →
  asString tv            >>= λ s  →
  guardEq s tag

-- The elements of a JSON array, each extracted with `f`.
extractListOf : ∀ {A : Set} → (JSON → Maybe A) → JSON → Maybe (List A)
extractListOf f v = asArray v >>= mapM f

------------------------------------------------------------------------
-- Coordinate & Position Extraction
------------------------------------------------------------------------

-- Extract a single [longitude, latitude] pair
extractPosition : JSON → Maybe Position
extractPosition v = asArray v >>= λ where
  (lonV ∷ latV ∷ []) →
    asNumber lonV >>= λ lon →
    asNumber latV >>= λ lat →
    just (pos lon lat)
  _ → nothing

-- A line or ring of positions
extractPositions : JSON → Maybe (List Position)
extractPositions = extractListOf extractPosition

-- Polygon rings: list of linear rings (outer + inner holes)
extractRings : JSON → Maybe (List (List Position))
extractRings = extractListOf extractPositions

-- Multi-polygon: list of polygon rings
extractPolygons : JSON → Maybe (List (List (List Position)))
extractPolygons = extractListOf extractRings

------------------------------------------------------------------------
-- Geometry Extraction
------------------------------------------------------------------------

extractCoordinates : Kind → JSON → Maybe Geometry
extractCoordinates pointK           v = Maybe.map pointG (extractPosition v)
extractCoordinates multiPointK      v = Maybe.map multiPointG (extractPositions v)
extractCoordinates lineStringK      v = Maybe.map lineStringG (extractPositions v)
extractCoordinates multiLineStringK v = Maybe.map multiLineStringG (extractRings v)
extractCoordinates polygonK         v = Maybe.map polygonG (extractRings v)
extractCoordinates multiPolygonK    v = Maybe.map multiPolygonG (extractPolygons v)

extractGeometryFromObject : Object → Maybe Geometry
extractGeometryFromObject kvs =
  lookupField "type" kvs        >>= λ typeVal   →
  asString typeVal              >>= λ typeName  →
  parseKind typeName            >>= λ kind      →
  lookupField "coordinates" kvs >>= λ coordsVal →
  extractCoordinates kind coordsVal

extractGeometry : JSON → Maybe Geometry
extractGeometry v = asObject v >>= extractGeometryFromObject

------------------------------------------------------------------------
-- Feature Extraction
------------------------------------------------------------------------

-- A feature's optional `id` and `properties` members are read leniently.
featureOf : Object → Geometry → Feature
featureOf kvs geom =
  feature (lookupField "id" kvs >>= asString)
          geom
          (Maybe.fromMaybe [] (lookupField "properties" kvs >>= asObject))

extractFeatureFromObject : Object → Maybe Feature
extractFeatureFromObject kvs =
  hasType "Feature" kvs        >>= λ _        →
  lookupField "geometry" kvs   >>= λ geomVal  →
  extractGeometry geomVal      >>= λ geom     →
  just (featureOf kvs geom)

extractFeature : JSON → Maybe Feature
extractFeature v = asObject v >>= extractFeatureFromObject

------------------------------------------------------------------------
-- FeatureCollection Extraction
------------------------------------------------------------------------

extractBBox : JSON → Maybe BBox
extractBBox v = asArray v >>= λ where
  (minLonV ∷ minLatV ∷ maxLonV ∷ maxLatV ∷ []) →
    asNumber minLonV >>= λ minLon →
    asNumber minLatV >>= λ minLat →
    asNumber maxLonV >>= λ maxLon →
    asNumber maxLatV >>= λ maxLat →
    just (bbox minLon minLat maxLon maxLat)
  _ → nothing

-- The optional `bbox` member is read leniently.
collectionOf : Object → List Feature → FeatureCollection
collectionOf kvs feats =
  featureCollection feats (lookupField "bbox" kvs >>= extractBBox)

extractFeatureCollectionFromObject : Object → Maybe FeatureCollection
extractFeatureCollectionFromObject kvs =
  hasType "FeatureCollection" kvs >>= λ _        →
  lookupField "features" kvs      >>= λ featVal  →
  asArray featVal                 >>= λ featArr  →
  mapM extractFeature featArr     >>= λ feats    →
  just (collectionOf kvs feats)

extractFeatureCollection : JSON → Maybe FeatureCollection
extractFeatureCollection v = asObject v >>= extractFeatureCollectionFromObject
