{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Deciding GeoJSON conformance, and extraction through the decision.
--
-- `validateAndExtract` decides conformance and then extracts totally from
-- the evidence; `validateAndExtract-correct` shows this is exactly
-- `extractFeatureCollection`.
module GeoAgda.Model.GeoJSON.Validate where

open import Data.Empty using (⊥-elim)
open import Data.Product using (_,_; ∃; proj₁; proj₂)
open import Data.Maybe using (Maybe; just; nothing)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; sym; trans)
open import Relation.Nullary.Decidable using (Dec; yes; no)

open import Data.JSON.AST using (JSON)
open import Data.JSON.Conformance
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Schema
open import GeoAgda.Model.GeoJSON.Extraction
open import GeoAgda.Model.GeoJSON.Conformance
open import GeoAgda.Model.GeoJSON.Properties

------------------------------------------------------------------------
-- Coordinates (decided directly from the schema)
------------------------------------------------------------------------

checkPosition : (v : JSON) → Dec (v ⊨ positionSchema)
checkPosition = decTuple2 decNumber decNumber

checkLineString : (v : JSON) → Dec (v ⊨ positionsSchema)
checkLineString = decList checkPosition

checkPolygon : (v : JSON) → Dec (v ⊨ ringsSchema)
checkPolygon = decList checkLineString

------------------------------------------------------------------------
-- Deciding through a sound and complete extractor
------------------------------------------------------------------------

private
  module Via {X : Set} {P : JSON → Set}
             (extract : JSON → Maybe X) (decode : ∀ {v} → P v → X)
             (sound    : ∀ {v} (p : P v) → extract v ≡ just (decode p))
             (complete : ∀ {v x} → extract v ≡ just x → ∃ λ (p : P v) → decode p ≡ x)
             where

    decide : (v : JSON) → Dec (P v)
    decide v with extract v in eq
    ... | nothing = no λ p → nothing≢just (trans (sym eq) (sound p))
      where nothing≢just : ∀ {A : Set} {x : A} → nothing ≡ just x → _
            nothing≢just ()
    ... | just x  = yes (proj₁ (complete eq))

    -- What the decision extracts.
    viaDecision : ∀ {v} → Dec (P v) → Maybe X
    viaDecision (yes p) = just (decode p)
    viaDecision (no _)  = nothing

    -- … agrees with `extract`, whichever way the decision was made.
    viaDecision-correct : ∀ v (d : Dec (P v)) → viaDecision d ≡ extract v
    viaDecision-correct v (yes p) = sym (sound p)
    viaDecision-correct v (no ¬p) with extract v in eq
    ... | nothing = refl
    ... | just x  = ⊥-elim (¬p (proj₁ (complete eq)))

------------------------------------------------------------------------
-- Geometries, features, feature collections
------------------------------------------------------------------------

private
  module G = Via {P = GeometryEvidence} extractGeometry extractGeometryFromEvidence geometry-sound geometry-complete
  module F = Via {P = FeatureEvidence} extractFeature extractFeatureFromEvidence feature-sound feature-complete
  module C = Via {P = FeatureCollectionEvidence} extractFeatureCollection extractFeatureCollectionFromEvidence
                 featureCollection-sound featureCollection-complete

checkGeometry : (v : JSON) → Dec (GeometryEvidence v)
checkGeometry = G.decide

checkFeature : (v : JSON) → Dec (FeatureEvidence v)
checkFeature = F.decide

checkFeatureCollection : (v : JSON) → Dec (FeatureCollectionEvidence v)
checkFeatureCollection = C.decide

-- Decide conformance once, then extract totally from the evidence.
validateAndExtract : JSON → Maybe FeatureCollection
validateAndExtract v = C.viaDecision (checkFeatureCollection v)

-- Validation followed by total extraction is exactly partial extraction.
validateAndExtract-correct : ∀ v → validateAndExtract v ≡ extractFeatureCollection v
validateAndExtract-correct v = C.viaDecision-correct v (checkFeatureCollection v)
