{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Model.GeoJSON.Types where

open import Data.String using (String)
open import Data.List using (List)
open import Data.Product using (_×_)
open import Data.Maybe using (Maybe)

open import Data.JSON.AST using (JSONNumber; JSON)

------------------------------------------------------------------------
-- GeoJSON Position (Coordinates)
------------------------------------------------------------------------

-- A Position in RFC 7946 is an array of coordinates: [longitude, latitude]
-- Represented with exact JSONNumber arithmetic
record Position : Set where
  constructor pos
  field
    lon : JSONNumber
    lat : JSONNumber

------------------------------------------------------------------------
-- GeoJSON Geometries
------------------------------------------------------------------------

data Geometry : Set where
  pointG              : Position → Geometry
  multiPointG         : List Position → Geometry
  lineStringG         : List Position → Geometry
  multiLineStringG    : List (List Position) → Geometry
  polygonG            : List (List Position) → Geometry
  multiPolygonG       : List (List (List Position)) → Geometry
  geometryCollectionG : List Geometry → Geometry

------------------------------------------------------------------------
-- GeoJSON Bounding Box
------------------------------------------------------------------------

record BBox : Set where
  constructor bbox
  field
    minLon : JSONNumber
    minLat : JSONNumber
    maxLon : JSONNumber
    maxLat : JSONNumber

------------------------------------------------------------------------
-- GeoJSON Properties, Features, and FeatureCollections
------------------------------------------------------------------------

-- Feature properties are arbitrary JSON key-value mappings
Properties : Set
Properties = List (String × JSON)

record Feature : Set where
  constructor feature
  field
    id         : Maybe String
    geometry   : Geometry
    properties : Properties

record FeatureCollection : Set where
  constructor featureCollection
  field
    features    : List Feature
    boundingBox : Maybe BBox
