{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Model.GeoJSON.Conformance where

open import Data.Bool using (Bool; true; false)
open import Data.String as String using (String)
open import Data.String.Properties using (_≟_)
open import Data.List as List using (List; []; _∷_; map)
open import Data.List.Relation.Unary.All as All using (All; []; _∷_)
open import Data.Product using (_×_; _,_; ∃; ∃₂; proj₁; proj₂)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Unit using (⊤; tt)
open import Data.Empty using (⊥; ⊥-elim)
open import Relation.Nullary.Decidable using (Dec; yes; no)
open import Relation.Nullary.Negation using (¬_; contradiction)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; sym; trans; subst)
open import Data.Maybe.Properties using (just-injective)
open import Function using (_∘_; _$_)

open import Data.JSON.AST using (JSON; JSONNumber)
open import Data.JSON.Schema using (asArray; asObject; asString; lookupField)
open import Data.JSON.Conformance
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

data GeometryEvidence (v : JSON) : Set where
  pointEv   : v ⊨ pointGeomSchema   → GeometryEvidence v
  lineEv    : v ⊨ lineGeomSchema    → GeometryEvidence v
  polygonEv : v ⊨ polygonGeomSchema → GeometryEvidence v

data FeatureEvidence (v : JSON) : Set where
  featureEv : ∀ {kvs geomVal} →
              asObject v ≡ just kvs →
              (evType : FieldEvidence kvs "type" (sExactString "Feature")) →
              (eqGeom : lookupField "geometry" kvs ≡ just geomVal) →
              GeometryEvidence geomVal →
              FeatureEvidence v

data FeatureCollectionEvidence (v : JSON) : Set where
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

checkPosition : (v : JSON) → Dec (v ⊨ positionSchema)
checkPosition = decTuple2 decNumber decNumber

checkLineString : (v : JSON) → Dec (v ⊨ lineStringSchema)
checkLineString = decList checkPosition

checkPolygon : (v : JSON) → Dec (v ⊨ polygonSchema)
checkPolygon = decList checkLineString

private
  just≢nothing : ∀ {A : Set} {x : A} → just x ≡ nothing → ⊥
  just≢nothing ()

  -- Two views of the same value's fields agree.
  kvs-eq : ∀ {v kvs kvs′} → asObject v ≡ just kvs → asObject v ≡ just kvs′ → kvs′ ≡ kvs
  kvs-eq e e′ = just-injective (trans (sym e′) e)

  castField : ∀ {kvs kvs′ k s} → kvs′ ≡ kvs → FieldEvidence kvs′ k s → FieldEvidence kvs k s
  castField refl f = f

  castFields : ∀ {kvs kvs′ reqs} → kvs′ ≡ kvs →
               AllFieldsEvidence kvs′ reqs → AllFieldsEvidence kvs reqs
  castFields refl f = f

  headField : ∀ {kvs k s reqs} → AllFieldsEvidence kvs ((k , s) ∷ reqs) → FieldEvidence kvs k s
  headField (consFields f _) = f

  tailFields : ∀ {kvs k s reqs} → AllFieldsEvidence kvs ((k , s) ∷ reqs) → AllFieldsEvidence kvs reqs
  tailFields (consFields _ fs) = fs

  -- An object whose fields (as seen from the evidence) are those of `asObject v`.
  objectFields : ∀ {v kvs reqs} → asObject v ≡ just kvs → v ⊨ sObjectReq reqs →
                 AllFieldsEvidence kvs reqs
  objectFields e (evObject e′ flds) = castFields (kvs-eq e e′) flds

  lookup-cast : ∀ {kvs kvs′ k g} → kvs′ ≡ kvs → lookupField k kvs′ ≡ just g → lookupField k kvs ≡ just g
  lookup-cast refl e = e

-- `{"type": tag, "coordinates": …}` with coordinates of the given schema.
checkTyped : (tag : String) (coords : Schema) → ((v : JSON) → Dec (v ⊨ coords)) →
             (v : JSON) → Dec (v ⊨ sObjectReq (("type" , sExactString tag) ∷ ("coordinates" , coords) ∷ []))
checkTyped tag coords check v with asObject v in eqObj
... | nothing  = no λ { (evObject e _) → just≢nothing (trans (sym e) eqObj) }
... | just kvs with decField (decExactString tag) "type" kvs
...   | no ¬t  = no λ ev → ¬t (headField (objectFields eqObj ev))
...   | yes ft with decField check "coordinates" kvs
...     | no ¬c  = no λ ev → ¬c (headField (tailFields (objectFields eqObj ev)))
...     | yes fc = yes (evObject eqObj (consFields ft (consFields fc nilFields)))

checkPointGeom : (v : JSON) → Dec (v ⊨ pointGeomSchema)
checkPointGeom = checkTyped "Point" positionSchema checkPosition

checkLineGeom : (v : JSON) → Dec (v ⊨ lineGeomSchema)
checkLineGeom = checkTyped "LineString" lineStringSchema checkLineString

checkPolygonGeom : (v : JSON) → Dec (v ⊨ polygonGeomSchema)
checkPolygonGeom = checkTyped "Polygon" polygonSchema checkPolygon

checkGeometry : (v : JSON) → Dec (GeometryEvidence v)
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

checkFeature : (v : JSON) → Dec (FeatureEvidence v)
checkFeature v with asObject v in eqObj
... | nothing  = no λ { (featureEv e _ _ _) → just≢nothing (trans (sym e) eqObj) }
... | just kvs with decField (decExactString "Feature") "type" kvs
...   | no ¬t  = no λ { (featureEv e ft _ _) → ¬t (castField (kvs-eq eqObj e) ft) }
...   | yes ft with lookupField "geometry" kvs in eqGeom
...     | nothing      = no λ { (featureEv e _ eq _) →
            just≢nothing (trans (sym (lookup-cast (kvs-eq eqObj e) eq)) eqGeom) }
...     | just geomVal with checkGeometry geomVal
...       | no ¬g  = no λ { (featureEv e _ eq gEv) →
            ¬g (subst GeometryEvidence
                      (just-injective (trans (sym (lookup-cast (kvs-eq eqObj e) eq)) eqGeom)) gEv) }
...       | yes gEv = yes (featureEv eqObj ft eqGeom gEv)

checkFeatureCollection : (v : JSON) → Dec (FeatureCollectionEvidence v)
checkFeatureCollection v with asObject v in eqObj
... | nothing  = no λ { (featureCollectionEv e _ _ _ _) → just≢nothing (trans (sym e) eqObj) }
... | just kvs with decField (decExactString "FeatureCollection") "type" kvs
...   | no ¬t  = no λ { (featureCollectionEv e ft _ _ _) → ¬t (castField (kvs-eq eqObj e) ft) }
...   | yes ft with lookupField "features" kvs in eqFeats
...     | nothing       = no λ { (featureCollectionEv e _ eq _ _) →
            just≢nothing (trans (sym (lookup-cast (kvs-eq eqObj e) eq)) eqFeats) }
...     | just featVals with asArray featVals in eqArr
...       | nothing   = no λ { (featureCollectionEv e _ eq eqA _) →
            just≢nothing (trans (sym (subst (λ g → asArray g ≡ just _)
                                           (just-injective (trans (sym (lookup-cast (kvs-eq eqObj e) eq)) eqFeats))
                                           eqA))
                                eqArr) }
...       | just xs   with All.all? checkFeature xs
...         | no ¬all  = no λ { (featureCollectionEv e _ eq eqA allEv) →
            ¬all (subst (All FeatureEvidence)
                        (just-injective (trans (sym (subst (λ g → asArray g ≡ just _)
                                                           (just-injective (trans (sym (lookup-cast (kvs-eq eqObj e) eq)) eqFeats))
                                                           eqA))
                                               eqArr))
                        allEv) }
...         | yes allEv = yes (featureCollectionEv eqObj ft eqFeats eqArr allEv)

-- Type-directed extraction: validates schema once, then executes total proof-shortcut extraction
validateAndExtract : JSON → Maybe FeatureCollection
validateAndExtract v with checkFeatureCollection v
... | yes ev = just (extractFeatureCollectionFromEvidence ev)
... | no  _  = nothing
