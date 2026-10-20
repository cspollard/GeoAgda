{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Model.GeoJSON.Extraction where

open import Level using (0ℓ)
open import Data.Bool using (Bool; true; false; if_then_else_)
open import Data.String as String using (String)
open import Data.String.Properties using (_==_)
open import Data.List as List using (List; []; _∷_; map)
open import Data.Product using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Function using (_∘_; _$_)

open import Data.JSON.AST using (JSON; JSONNumber)
open import Data.JSON.Schema using (asArray; asObject; asString; asNumber; lookupField)
open import GeoAgda.Model.GeoJSON.Types

------------------------------------------------------------------------
-- Coordinate & Position Extraction
------------------------------------------------------------------------

mkPos : Maybe JSONNumber → Maybe JSONNumber → Maybe Position
mkPos (just lon) (just lat) = just (pos lon lat)
mkPos _          _          = nothing

-- Extract a single [longitude, latitude] pair
extractPosition : JSON → Maybe Position
extractPosition v with asArray v
... | just (lonV ∷ latV ∷ []) = mkPos (asNumber lonV) (asNumber latV)
... | _                       = nothing

-- Helper: Map extraction across a list, failing if any element fails
mapM : ∀ {A B : Set} → (A → Maybe B) → List A → Maybe (List B)
mapM _ []       = just []
mapM f (x ∷ xs) = do
  y  ← f x
  ys ← mapM f xs
  just (y ∷ ys)

-- Extract a line or ring of positions
extractPositions : JSON → Maybe (List Position)
extractPositions v with asArray v
... | nothing   = nothing
... | just arrs = mapM extractPosition arrs

-- Extract polygon rings: list of linear rings (outer + inner holes)
extractRings : JSON → Maybe (List (List Position))
extractRings v with asArray v
... | nothing   = nothing
... | just arrs = mapM extractPositions arrs

-- Extract multi-polygon: list of polygon rings
extractPolygons : JSON → Maybe (List (List (List Position)))
extractPolygons v with asArray v
... | nothing   = nothing
... | just arrs = mapM extractRings arrs

------------------------------------------------------------------------
-- Geometry Extraction
------------------------------------------------------------------------

extractGeometryFromObject : List (String × JSON) → Maybe Geometry
extractGeometryFromObject kvs = do
  typeVal   ← lookupField "type" kvs
  coordsVal ← lookupField "coordinates" kvs
  typeName  ← asString typeVal
  if typeName == "Point"
    then Maybe.map pointG (extractPosition coordsVal)
    else (if typeName == "MultiPoint"
          then Maybe.map multiPointG (extractPositions coordsVal)
          else (if typeName == "LineString"
                then Maybe.map lineStringG (extractPositions coordsVal)
                else (if typeName == "MultiLineString"
                      then Maybe.map multiLineStringG (extractRings coordsVal)
                      else (if typeName == "Polygon"
                            then Maybe.map polygonG (extractRings coordsVal)
                            else (if typeName == "MultiPolygon"
                                  then Maybe.map multiPolygonG (extractPolygons coordsVal)
                                  else nothing)))))

extractGeometry : JSON → Maybe Geometry
extractGeometry v with asObject v
... | nothing  = nothing
... | just kvs = extractGeometryFromObject kvs

------------------------------------------------------------------------
-- Feature Extraction
------------------------------------------------------------------------

extractFeatureFromObject : List (String × JSON) → Maybe Feature
extractFeatureFromObject kvs = do
  typeVal  ← lookupField "type" kvs
  geomVal  ← lookupField "geometry" kvs
  typeName ← asString typeVal
  if typeName == "Feature"
    then (do
      geom ← extractGeometry geomVal
      let idVal = lookupField "id" kvs >>= asString
          props = lookupField "properties" kvs >>= asObject
          finalProps = Maybe.fromMaybe [] props
      just (feature idVal geom finalProps))
    else nothing

extractFeature : JSON → Maybe Feature
extractFeature v with asObject v
... | nothing  = nothing
... | just kvs = extractFeatureFromObject kvs

------------------------------------------------------------------------
-- FeatureCollection Extraction
------------------------------------------------------------------------

extractBBox : JSON → Maybe BBox
extractBBox v with asArray v
... | just (minLonV ∷ minLatV ∷ maxLonV ∷ maxLatV ∷ []) = do
        minLon ← asNumber minLonV
        minLat ← asNumber minLatV
        maxLon ← asNumber maxLonV
        maxLat ← asNumber maxLatV
        just (bbox minLon minLat maxLon maxLat)
... | _ = nothing

extractFeatureCollectionFromObject : List (String × JSON) → Maybe FeatureCollection
extractFeatureCollectionFromObject kvs = do
  typeVal     ← lookupField "type" kvs
  featuresVal ← lookupField "features" kvs
  typeName    ← asString typeVal
  if typeName == "FeatureCollection"
    then (do
      featArr ← asArray featuresVal
      feats   ← mapM extractFeature featArr
      let mbBBox = lookupField "bbox" kvs >>= extractBBox
      just (featureCollection feats mbBBox))
    else nothing

extractFeatureCollection : JSON → Maybe FeatureCollection
extractFeatureCollection v with asObject v
... | nothing  = nothing
... | just kvs = extractFeatureCollectionFromObject kvs
