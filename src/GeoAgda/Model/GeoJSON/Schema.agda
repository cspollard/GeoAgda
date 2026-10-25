{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- The GeoJSON domain as JSON schemas: the shape of `coordinates` for each
-- geometry type, and the decoding of schema-typed values into the model.
module GeoAgda.Model.GeoJSON.Schema where

open import Data.String using (String)
open import Data.String.Properties using (_≟_)
open import Data.List using (List; []; _∷_; map)
open import Data.Product using (_,_)
open import Data.Maybe using (Maybe; just; nothing)
open import Relation.Nullary.Decidable using (yes; no)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Data.JSON.Conformance using (Schema; sNumber; sList; sTuple2; ⟦_⟧)
open import GeoAgda.Model.GeoJSON.Types

------------------------------------------------------------------------
-- Coordinate schemas (RFC 7946 §3.1)
------------------------------------------------------------------------

-- [longitude, latitude]
positionSchema : Schema
positionSchema = sTuple2 sNumber sNumber

-- a point list (MultiPoint, LineString, a linear ring)
positionsSchema : Schema
positionsSchema = sList positionSchema

-- a list of rings (Polygon, MultiLineString)
ringsSchema : Schema
ringsSchema = sList positionsSchema

-- a list of polygons (MultiPolygon)
polygonsSchema : Schema
polygonsSchema = sList ringsSchema

toPosition : ⟦ positionSchema ⟧ → Position
toPosition (lon , lat) = pos lon lat

toPositions : ⟦ positionsSchema ⟧ → List Position
toPositions = map toPosition

toRings : ⟦ ringsSchema ⟧ → List (List Position)
toRings = map toPositions

toPolygons : ⟦ polygonsSchema ⟧ → List (List (List Position))
toPolygons = map toRings

------------------------------------------------------------------------
-- Geometry kinds
------------------------------------------------------------------------

-- The geometry types that carry `coordinates`.
data Kind : Set where
  pointK multiPointK lineStringK multiLineStringK polygonK multiPolygonK : Kind

allKinds : List Kind
allKinds = pointK ∷ multiPointK ∷ lineStringK ∷ multiLineStringK ∷ polygonK ∷ multiPolygonK ∷ []

-- The value of the `type` member.
kindName : Kind → String
kindName pointK           = "Point"
kindName multiPointK      = "MultiPoint"
kindName lineStringK      = "LineString"
kindName multiLineStringK = "MultiLineString"
kindName polygonK         = "Polygon"
kindName multiPolygonK    = "MultiPolygon"

coordinatesSchema : Kind → Schema
coordinatesSchema pointK           = positionSchema
coordinatesSchema multiPointK      = positionsSchema
coordinatesSchema lineStringK      = positionsSchema
coordinatesSchema multiLineStringK = ringsSchema
coordinatesSchema polygonK         = ringsSchema
coordinatesSchema multiPolygonK    = polygonsSchema

fromCoordinates : (k : Kind) → ⟦ coordinatesSchema k ⟧ → Geometry
fromCoordinates pointK           c = pointG (toPosition c)
fromCoordinates multiPointK      c = multiPointG (toPositions c)
fromCoordinates lineStringK      c = lineStringG (toPositions c)
fromCoordinates multiLineStringK c = multiLineStringG (toRings c)
fromCoordinates polygonK         c = polygonG (toRings c)
fromCoordinates multiPolygonK    c = multiPolygonG (toPolygons c)

------------------------------------------------------------------------
-- Reading the `type` member
------------------------------------------------------------------------

parseKindIn : String → List Kind → Maybe Kind
parseKindIn s []       = nothing
parseKindIn s (k ∷ ks) with s ≟ kindName k
... | yes _ = just k
... | no  _ = parseKindIn s ks

parseKind : String → Maybe Kind
parseKind s = parseKindIn s allKinds

parseKindIn-sound : ∀ {s k} ks → parseKindIn s ks ≡ just k → s ≡ kindName k
parseKindIn-sound []       ()
parseKindIn-sound {s} (k ∷ ks) eq with s ≟ kindName k
parseKindIn-sound (k ∷ ks) refl | yes p = p
... | no _ = parseKindIn-sound ks eq

parseKind-sound : ∀ {s k} → parseKind s ≡ just k → s ≡ kindName k
parseKind-sound = parseKindIn-sound allKinds

parseKind-kindName : ∀ k → parseKind (kindName k) ≡ just k
parseKind-kindName pointK           = refl
parseKind-kindName multiPointK      = refl
parseKind-kindName lineStringK      = refl
parseKind-kindName multiLineStringK = refl
parseKind-kindName polygonK         = refl
parseKind-kindName multiPolygonK    = refl
