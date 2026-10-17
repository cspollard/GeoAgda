{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Model.GeoJSON.Conformance where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.String.Base as String using (String)
open import Data.String.Properties using (_≟_)
open import Data.List.Base as List using (List; []; _∷_; map)
open import Data.List.Relation.Unary.All as All using (All; []; _∷_)
open import Data.Product.Base using (_×_; _,_; ∃; ∃₂; proj₁; proj₂)
open import Data.Maybe.Base as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Unit.Base using (⊤; tt)
open import Data.Empty using (⊥; ⊥-elim)
open import Relation.Nullary.Decidable using (Dec; yes; no)
open import Relation.Nullary.Negation using (¬_; contradiction)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Function.Base using (_∘_; _$_)

open import GeoAgda.Data.JSON.AST using (JSONValue; JSONNumber)
open import GeoAgda.Data.JSON.Schema using (asArray; asObject; asString; lookupField)
open import GeoAgda.Data.JSON.Conformance
open import GeoAgda.Model.GeoJSON.Types

------------------------------------------------------------------------
-- GeoJSON Domain Schemas
------------------------------------------------------------------------

positionSchema : Schema
positionSchema = sTuple2 sNumber sNumber

lineStringSchema : Schema
lineStringSchema = sList positionSchema

polygonSchema : Schema
polygonSchema = sList (sList positionSchema)

pointGeomSchema : Schema
pointGeomSchema =
  sObjectReq (("type" , sExactString "Point") ∷ ("coordinates" , positionSchema) ∷ [])

lineGeomSchema : Schema
lineGeomSchema =
  sObjectReq (("type" , sExactString "LineString") ∷ ("coordinates" , lineStringSchema) ∷ [])

polygonGeomSchema : Schema
polygonGeomSchema =
  sObjectReq (("type" , sExactString "Polygon") ∷ ("coordinates" , polygonSchema) ∷ [])

------------------------------------------------------------------------
-- Compound Evidence Types
------------------------------------------------------------------------

data GeometryEvidence (v : JSONValue) : Set where
  pointEv   : v ⊨ pointGeomSchema   → GeometryEvidence v
  lineEv    : v ⊨ lineGeomSchema    → GeometryEvidence v
  polygonEv : v ⊨ polygonGeomSchema → GeometryEvidence v

data FeatureEvidence (v : JSONValue) : Set where
  featureEv : ∀ {kvs geomVal} →
              asObject v ≡ just kvs →
              (evType : FieldEvidence kvs "type" (sExactString "Feature")) →
              (eqGeom : lookupField "geometry" kvs ≡ just geomVal) →
              GeometryEvidence geomVal →
              FeatureEvidence v

data FeatureCollectionEvidence (v : JSONValue) : Set where
  featureCollectionEv : ∀ {kvs featVals xs} →
                        asObject v ≡ just kvs →
                        (evType : FieldEvidence kvs "type" (sExactString "FeatureCollection")) →
                        (eqFeats : lookupField "features" kvs ≡ just featVals) →
                        asArray featVals ≡ just xs →
                        All FeatureEvidence xs →
                        FeatureCollectionEvidence v

------------------------------------------------------------------------
-- Proof-Carrying Total Extractors ("Extraction Shortcuts")
------------------------------------------------------------------------

-- 1. Position projection: total, returns Position directly without Maybe
extractPositionFromEvidence : ∀ {v} → v ⊨ positionSchema → Position
extractPositionFromEvidence p =
  let (lon , lat) = decodeFromEvidence p
  in pos lon lat

-- 2. LineString projection: total, maps over verified evidence
extractLineStringFromEvidence : ∀ {v} → v ⊨ lineStringSchema → List Position
extractLineStringFromEvidence p =
  map (λ (lon , lat) → pos lon lat) (decodeFromEvidence p)

-- 3. Polygon projection: total, maps over verified nested rings
extractPolygonFromEvidence : ∀ {v} → v ⊨ polygonSchema → List (List Position)
extractPolygonFromEvidence p =
  map (map (λ (lon , lat) → pos lon lat)) (decodeFromEvidence p)

-- 4. Geometry projection: total, projects from certified evidence
extractGeometryFromEvidence : ∀ {v} → GeometryEvidence v → Geometry
extractGeometryFromEvidence (pointEv p) =
  let (_ , (lon , lat) , _) = decodeFromEvidence p
  in pointG (pos lon lat)
extractGeometryFromEvidence (lineEv p) =
  let (_ , pts , _) = decodeFromEvidence p
  in lineStringG (map (λ (lon , lat) → pos lon lat) pts)
extractGeometryFromEvidence (polygonEv p) =
  let (_ , rings , _) = decodeFromEvidence p
  in polygonG (map (map (λ (lon , lat) → pos lon lat)) rings)

-- 5. Feature projection: total
extractFeatureFromEvidence : ∀ {v} → FeatureEvidence v → Feature
extractFeatureFromEvidence (featureEv {kvs = kvs} _ _ _ geomEv) =
  let idVal = lookupField "id" kvs >>= asString
      props = Maybe.fromMaybe [] (lookupField "properties" kvs >>= asObject)
      geom  = extractGeometryFromEvidence geomEv
  in feature idVal geom props

-- 6. FeatureCollection projection: total, maps over All FeatureEvidence
extractFeatureCollectionFromEvidence : ∀ {v} → FeatureCollectionEvidence v → FeatureCollection
extractFeatureCollectionFromEvidence (featureCollectionEv {kvs = kvs} _ _ _ _ allFeats) =
  let feats = extractFeaturesList allFeats
  in featureCollection feats nothing
  where
    extractFeaturesList : ∀ {xs} → All FeatureEvidence xs → List Feature
    extractFeaturesList []         = []
    extractFeaturesList (fEv ∷ fs) = extractFeatureFromEvidence fEv ∷ extractFeaturesList fs

------------------------------------------------------------------------
-- Decidable Verification & Shortcut Extraction Driver
------------------------------------------------------------------------

checkPosition : (v : JSONValue) → Dec (v ⊨ positionSchema)
checkPosition = decTuple2 decNumber decNumber

checkLineString : (v : JSONValue) → Dec (v ⊨ lineStringSchema)
checkLineString = decList checkPosition

checkPolygon : (v : JSONValue) → Dec (v ⊨ polygonSchema)
checkPolygon = decList checkLineString

checkPointGeom : (v : JSONValue) → Dec (v ⊨ pointGeomSchema)
checkPointGeom v with asObject v in eqObj
... | nothing  = no (λ where (evObject eq _) → contradiction eq λ ())
... | just kvs with decField (decExactString "Point") "type" kvs
...   | no ¬t  = no (λ where (evObject _ (consFields ft _)) → ¬t ft)
...   | yes ft with decField checkPosition "coordinates" kvs
...     | no ¬c  = no (λ where (evObject _ (consFields _ (consFields fc _))) → ¬c fc)
...     | yes fc = yes (evObject eqObj (consFields ft (consFields fc nilFields)))

checkLineGeom : (v : JSONValue) → Dec (v ⊨ lineGeomSchema)
checkLineGeom v with asObject v in eqObj
... | nothing  = no (λ where (evObject eq _) → contradiction eq λ ())
... | just kvs with decField (decExactString "LineString") "type" kvs
...   | no ¬t  = no (λ where (evObject _ (consFields ft _)) → ¬t ft)
...   | yes ft with decField checkLineString "coordinates" kvs
...     | no ¬c  = no (λ where (evObject _ (consFields _ (consFields fc _))) → ¬c fc)
...     | yes fc = yes (evObject eqObj (consFields ft (consFields fc nilFields)))

checkPolygonGeom : (v : JSONValue) → Dec (v ⊨ polygonGeomSchema)
checkPolygonGeom v with asObject v in eqObj
... | nothing  = no (λ where (evObject eq _) → contradiction eq λ ())
... | just kvs with decField (decExactString "Polygon") "type" kvs
...   | no ¬t  = no (λ where (evObject _ (consFields ft _)) → ¬t ft)
...   | yes ft with decField checkPolygon "coordinates" kvs
...     | no ¬c  = no (λ where (evObject _ (consFields _ (consFields fc _))) → ¬c fc)
...     | yes fc = yes (evObject eqObj (consFields ft (consFields fc nilFields)))

checkGeometry : (v : JSONValue) → Dec (GeometryEvidence v)
checkGeometry v with checkPointGeom v
... | yes p = yes (pointEv p)
... | no ¬p with checkLineGeom v
...   | yes l = yes (lineEv l)
...   | no ¬l with checkPolygonGeom v
...     | yes poly = yes (polygonEv poly)
...     | no ¬poly = no (λ where
            (pointEv p)   → ¬p p
            (lineEv l)    → ¬l l
            (polygonEv q) → ¬poly q)

checkFeature : (v : JSONValue) → Dec (FeatureEvidence v)
checkFeature v with asObject v in eqObj
... | nothing  = no (λ where (featureEv eq _ _ _) → contradiction eq λ ())
... | just kvs with decField (decExactString "Feature") "type" kvs
...   | no ¬t  = no (λ where (featureEv _ ft _ _) → ¬t ft)
...   | yes ft with lookupField "geometry" kvs in eqGeom
...     | nothing      = no (λ where (featureEv _ _ eq _) → contradiction eq λ ())
...     | just geomVal with checkGeometry geomVal
...       | no ¬g  = no (λ where (featureEv _ _ _ gEv) → ¬g gEv)
...       | yes gEv = yes (featureEv eqObj ft eqGeom gEv)

checkFeatureCollection : (v : JSONValue) → Dec (FeatureCollectionEvidence v)
checkFeatureCollection v with asObject v in eqObj
... | nothing  = no (λ where (featureCollectionEv eq _ _ _ _) → contradiction eq λ ())
... | just kvs with decField (decExactString "FeatureCollection") "type" kvs
...   | no ¬t  = no (λ where (featureCollectionEv _ ft _ _ _) → ¬t ft)
...   | yes ft with lookupField "features" kvs in eqFeats
...     | nothing       = no (λ where (featureCollectionEv _ _ eq _ _) → contradiction eq λ ())
...     | just featVals with asArray featVals in eqArr
...       | nothing   = no (λ where (featureCollectionEv _ _ _ eq _) → contradiction eq λ ())
...       | just xs   with All.all? checkFeature xs
...         | no ¬all  = no (λ where (featureCollectionEv _ _ _ _ allEv) → ¬all allEv)
...         | yes allEv = yes (featureCollectionEv eqObj ft eqFeats eqArr allEv)

-- Type-directed extraction: validates schema once, then executes total proof-shortcut extraction
validateAndExtract : JSONValue → Maybe FeatureCollection
validateAndExtract v with checkFeatureCollection v
... | yes ev = just (extractFeatureCollectionFromEvidence ev)
... | no  _  = nothing
