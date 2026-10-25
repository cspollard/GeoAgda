{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Declarative GeoJSON validity, and total extraction from its evidence.
--
-- `GeometryEvidence v`, `FeatureEvidence v` and `FeatureCollectionEvidence v`
-- say that `v` is a well-formed GeoJSON geometry / feature / feature
-- collection, building on the schema evidence of `Data.JSON.Conformance`.
-- Extraction from evidence is total.  `GeoAgda.Model.GeoJSON.Properties`
-- proves it agrees with the partial extractors of
-- `GeoAgda.Model.GeoJSON.Extraction`.
module GeoAgda.Model.GeoJSON.Conformance where

open import Data.String using (String)
open import Data.List using (List; []; _∷_)
open import Data.List.Relation.Unary.All using (All; reduce)
open import Data.Product using (_×_)
open import Data.Maybe using (Maybe; just)
open import Relation.Binary.PropositionalEquality using (_≡_)

open import Data.JSON.AST using (JSON)
open import Data.JSON.Schema using (asArray; asObject; lookupField)
open import Data.JSON.Conformance
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Schema
open import GeoAgda.Model.GeoJSON.Extraction using (featureOf; collectionOf)

------------------------------------------------------------------------
-- Evidence
------------------------------------------------------------------------

-- `{"type": <kind>, "coordinates": <coordinates of that kind>, …}`
record GeometryEvidence (v : JSON) : Set where
  constructor geometryEv
  field
    {kvs}    : List (String × JSON)
    kind     : Kind
    isObject : asObject v ≡ just kvs
    typeEv   : FieldEvidence kvs "type" (sExactString (kindName kind))
    coordsEv : FieldEvidence kvs "coordinates" (coordinatesSchema kind)

-- `{"type": "Feature", "geometry": <geometry>, …}`
record FeatureEvidence (v : JSON) : Set where
  constructor featureEv
  field
    {kvs}      : List (String × JSON)
    {geomVal}  : JSON
    isObject   : asObject v ≡ just kvs
    typeEv     : FieldEvidence kvs "type" (sExactString "Feature")
    geomLookup : lookupField "geometry" kvs ≡ just geomVal
    geomEv     : GeometryEvidence geomVal

-- `{"type": "FeatureCollection", "features": [<feature>, …], …}`
record FeatureCollectionEvidence (v : JSON) : Set where
  constructor featureCollectionEv
  field
    {kvs}        : List (String × JSON)
    {featVal}    : JSON
    {feats}      : List JSON
    isObject     : asObject v ≡ just kvs
    typeEv       : FieldEvidence kvs "type" (sExactString "FeatureCollection")
    featLookup   : lookupField "features" kvs ≡ just featVal
    isArray      : asArray featVal ≡ just feats
    featuresEv   : All FeatureEvidence feats

------------------------------------------------------------------------
-- Total extraction from evidence
------------------------------------------------------------------------

extractPositionFromEvidence : ∀ {v} → v ⊨ positionSchema → Position
extractPositionFromEvidence e = toPosition (decodeFromEvidence e)

extractLineStringFromEvidence : ∀ {v} → v ⊨ positionsSchema → List Position
extractLineStringFromEvidence e = toPositions (decodeFromEvidence e)

extractPolygonFromEvidence : ∀ {v} → v ⊨ ringsSchema → List (List Position)
extractPolygonFromEvidence e = toRings (decodeFromEvidence e)

extractGeometryFromEvidence : ∀ {v} → GeometryEvidence v → Geometry
extractGeometryFromEvidence (geometryEv k _ _ (fieldEv _ _ cEv)) =
  fromCoordinates k (decodeFromEvidence cEv)

extractFeatureFromEvidence : ∀ {v} → FeatureEvidence v → Feature
extractFeatureFromEvidence (featureEv {kvs} _ _ _ gEv) =
  featureOf kvs (extractGeometryFromEvidence gEv)

extractFeaturesFromEvidence : ∀ {vs} → All FeatureEvidence vs → List Feature
extractFeaturesFromEvidence = reduce extractFeatureFromEvidence

extractFeatureCollectionFromEvidence : ∀ {v} → FeatureCollectionEvidence v → FeatureCollection
extractFeatureCollectionFromEvidence (featureCollectionEv {kvs} _ _ _ _ fsEv) =
  collectionOf kvs (extractFeaturesFromEvidence fsEv)
