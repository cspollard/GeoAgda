{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Extraction is sound and complete for GeoJSON conformance:
--
--   * (sound)    evidence for `v` makes extraction succeed, with exactly the
--                value extracted from the evidence;
--   * (complete) whenever extraction succeeds, there is evidence for `v`
--                from which the same value is extracted.
module GeoAgda.Model.GeoJSON.Properties where

open import Data.List using (List; []; _∷_; map)
open import Data.List.Relation.Unary.All as All using (All; []; _∷_; reduce)
open import Data.Product using (_×_; _,_; ∃; proj₁; proj₂)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Maybe.Properties using (just-injective)
open import Data.Empty using (⊥-elim)
open import Data.String.Properties using (_≟_)
open import Data.Unit using (⊤; tt)
open import Relation.Binary.PropositionalEquality
open import Relation.Nullary.Decidable using (yes; no)

open import Data.JSON.AST using (JSON; JSONNumber)
open import Data.JSON.Schema using (asArray; asObject; asString; asNumber; lookupField)
open import Data.JSON.Conformance
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.GeoJSON.Schema
open import GeoAgda.Model.GeoJSON.Extraction
open import GeoAgda.Model.GeoJSON.Conformance

------------------------------------------------------------------------
-- Maybe plumbing
------------------------------------------------------------------------

private
  variable
    A B : Set

bind-just : ∀ {m : Maybe A} {f : A → Maybe B} {a} → m ≡ just a → (m >>= f) ≡ f a
bind-just refl = refl

bind-just⁻ : ∀ {f : A → Maybe B} {b} (m : Maybe A) →
             (m >>= f) ≡ just b → ∃ λ a → m ≡ just a × f a ≡ just b
bind-just⁻ (just a) eq = a , refl , eq
bind-just⁻ nothing  ()

map-just : ∀ {f : A → B} {m : Maybe A} {a} → m ≡ just a → Maybe.map f m ≡ just (f a)
map-just refl = refl

map-just⁻ : ∀ {f : A → B} {b} (m : Maybe A) →
            Maybe.map f m ≡ just b → ∃ λ a → m ≡ just a × f a ≡ b
map-just⁻ (just a) refl = a , refl , refl
map-just⁻ nothing  ()

mapM-∷ : ∀ (f : A → Maybe B) x xs →
         mapM f (x ∷ xs) ≡ (f x >>= λ y → mapM f xs >>= λ ys → just (y ∷ ys))
mapM-∷ f x xs with f x | mapM f xs
... | nothing | _       = refl
... | just _  | nothing = refl
... | just _  | just _  = refl

------------------------------------------------------------------------
-- Lists
------------------------------------------------------------------------

mapM-sound : ∀ {P : A → Set} {f : A → Maybe B} {g : ∀ {x} → P x → B} →
             (∀ {x} (p : P x) → f x ≡ just (g p)) →
             ∀ {xs} (ps : All P xs) → mapM f xs ≡ just (reduce g ps)
mapM-sound f-sound []         = refl
mapM-sound {f = f} {g = g} f-sound {x ∷ xs} (p ∷ ps) =
  trans (mapM-∷ f x xs)
        (trans (bind-just (f-sound p))
               (bind-just (mapM-sound f-sound ps)))

mapM-complete : ∀ {P : A → Set} {f : A → Maybe B} {g : ∀ {x} → P x → B} →
                (∀ {x y} → f x ≡ just y → ∃ λ (p : P x) → g p ≡ y) →
                ∀ {xs ys} → mapM f xs ≡ just ys →
                ∃ λ (ps : All P xs) → reduce g ps ≡ ys
mapM-complete f-complete {[]}     refl = [] , refl
mapM-complete {f = f} {g = g} f-complete {x ∷ xs} eq
  with bind-just⁻ (f x) (subst (_≡ _) (mapM-∷ f x xs) eq)
... | y , fx , eq₁ with bind-just⁻ (mapM f xs) eq₁
...   | ys , mxs , eq₂ with f-complete fx | mapM-complete f-complete mxs
...     | p , gp | ps , gps = p ∷ ps , trans (cong₂ _∷_ gp gps) (just-injective eq₂)

-- Schema evidence for a list decodes to a list whose `map c` is the
-- `reduce` of the decoded elements.
map-decodeList : ∀ {S xs} (c : ⟦ S ⟧ → B) (ps : All (_⊨ S) xs) →
                 map c (decodeList ps) ≡ reduce (λ e → c (decodeFromEvidence e)) ps
map-decodeList c []         = refl
map-decodeList c (p ∷ ps)   = cong (c (decodeFromEvidence p) ∷_) (map-decodeList c ps)

extractListOf-sound :
  ∀ {S} {f : JSON → Maybe B} {c : ⟦ S ⟧ → B} →
  (∀ {v} (e : v ⊨ S) → f v ≡ just (c (decodeFromEvidence e))) →
  ∀ {v} (e : v ⊨ sList S) → extractListOf f v ≡ just (map c (decodeFromEvidence e))
extractListOf-sound {c = c} f-sound (evList eqA ps) =
  trans (bind-just eqA)
        (trans (mapM-sound f-sound ps)
               (cong just (sym (map-decodeList c ps))))

extractListOf-complete :
  ∀ {S} {f : JSON → Maybe B} {c : ⟦ S ⟧ → B} →
  (∀ {v x} → f v ≡ just x → ∃ λ (e : v ⊨ S) → c (decodeFromEvidence e) ≡ x) →
  ∀ {v xs} → extractListOf f v ≡ just xs →
  ∃ λ (e : v ⊨ sList S) → map c (decodeFromEvidence e) ≡ xs
extractListOf-complete {c = c} f-complete {v} eq
  with bind-just⁻ (asArray v) eq
... | ys , eqA , eqM with mapM-complete f-complete eqM
...   | ps , r = evList eqA ps , trans (map-decodeList c ps) r

------------------------------------------------------------------------
-- Coordinates
------------------------------------------------------------------------

position-sound : ∀ {v} (e : v ⊨ positionSchema) →
                 extractPosition v ≡ just (toPosition (decodeFromEvidence e))
position-sound (evTuple2 eqA (evNumber n₁ e₁) (evNumber n₂ e₂)) =
  trans (bind-just eqA) (trans (bind-just e₁) (bind-just e₂))

position-complete : ∀ {v p} → extractPosition v ≡ just p →
                    ∃ λ (e : v ⊨ positionSchema) → toPosition (decodeFromEvidence e) ≡ p
position-complete {v} eq with bind-just⁻ (asArray v) eq
... | []                   , _  , ()
... | _ ∷ []               , _  , ()
... | _ ∷ _ ∷ _ ∷ _        , _  , ()
... | x₁ ∷ x₂ ∷ []         , eqA , eq₁
    with bind-just⁻ (asNumber x₁) eq₁
...   | n₁ , e₁ , eq₂ with bind-just⁻ (asNumber x₂) eq₂
...     | n₂ , e₂ , eq₃ =
  evTuple2 eqA (evNumber n₁ e₁) (evNumber n₂ e₂) , just-injective eq₃

positions-sound : ∀ {v} (e : v ⊨ positionsSchema) →
                  extractPositions v ≡ just (toPositions (decodeFromEvidence e))
positions-sound = extractListOf-sound position-sound

positions-complete : ∀ {v ps} → extractPositions v ≡ just ps →
                     ∃ λ (e : v ⊨ positionsSchema) → toPositions (decodeFromEvidence e) ≡ ps
positions-complete = extractListOf-complete position-complete

rings-sound : ∀ {v} (e : v ⊨ ringsSchema) →
              extractRings v ≡ just (toRings (decodeFromEvidence e))
rings-sound = extractListOf-sound positions-sound

rings-complete : ∀ {v rs} → extractRings v ≡ just rs →
                 ∃ λ (e : v ⊨ ringsSchema) → toRings (decodeFromEvidence e) ≡ rs
rings-complete = extractListOf-complete positions-complete

polygons-sound : ∀ {v} (e : v ⊨ polygonsSchema) →
                 extractPolygons v ≡ just (toPolygons (decodeFromEvidence e))
polygons-sound = extractListOf-sound rings-sound

polygons-complete : ∀ {v ps} → extractPolygons v ≡ just ps →
                    ∃ λ (e : v ⊨ polygonsSchema) → toPolygons (decodeFromEvidence e) ≡ ps
polygons-complete = extractListOf-complete rings-complete

coordinates-sound : ∀ k {v} (e : v ⊨ coordinatesSchema k) →
                    extractCoordinates k v ≡ just (fromCoordinates k (decodeFromEvidence e))
coordinates-sound pointK           e = map-just (position-sound e)
coordinates-sound multiPointK      e = map-just (positions-sound e)
coordinates-sound lineStringK      e = map-just (positions-sound e)
coordinates-sound multiLineStringK e = map-just (rings-sound e)
coordinates-sound polygonK         e = map-just (rings-sound e)
coordinates-sound multiPolygonK    e = map-just (polygons-sound e)

coordinates-complete : ∀ k {v g} → extractCoordinates k v ≡ just g →
                       ∃ λ (e : v ⊨ coordinatesSchema k) → fromCoordinates k (decodeFromEvidence e) ≡ g
coordinates-complete pointK {v} eq with map-just⁻ (extractPosition v) eq
... | p , ep , refl with position-complete ep
...   | e , r = e , cong pointG r
coordinates-complete multiPointK {v} eq with map-just⁻ (extractPositions v) eq
... | p , ep , refl with positions-complete ep
...   | e , r = e , cong multiPointG r
coordinates-complete lineStringK {v} eq with map-just⁻ (extractPositions v) eq
... | p , ep , refl with positions-complete ep
...   | e , r = e , cong lineStringG r
coordinates-complete multiLineStringK {v} eq with map-just⁻ (extractRings v) eq
... | p , ep , refl with rings-complete ep
...   | e , r = e , cong multiLineStringG r
coordinates-complete polygonK {v} eq with map-just⁻ (extractRings v) eq
... | p , ep , refl with rings-complete ep
...   | e , r = e , cong polygonG r
coordinates-complete multiPolygonK {v} eq with map-just⁻ (extractPolygons v) eq
... | p , ep , refl with polygons-complete ep
...   | e , r = e , cong multiPolygonG r

------------------------------------------------------------------------
-- The `type` member
------------------------------------------------------------------------

guardEq-refl : ∀ s → guardEq s s ≡ just tt
guardEq-refl s with s ≟ s
... | yes _  = refl
... | no  ¬p = ⊥-elim (¬p refl)

guardEq-sound : ∀ {s t} → guardEq s t ≡ just tt → s ≡ t
guardEq-sound {s} {t} eq with s ≟ t
... | yes p = p

hasType-sound : ∀ {tag kvs} → FieldEvidence kvs "type" (sExactString tag) →
                hasType tag kvs ≡ just tt
hasType-sound {tag} (fieldEv tv eqT (evExactString eqS)) =
  trans (bind-just eqT) (trans (bind-just eqS) (guardEq-refl tag))

hasType-complete : ∀ {tag kvs} → hasType tag kvs ≡ just tt →
                   FieldEvidence kvs "type" (sExactString tag)
hasType-complete {tag} {kvs} eq with bind-just⁻ (lookupField "type" kvs) eq
... | tv , eqT , eq₁ with bind-just⁻ (asString tv) eq₁
...   | s , eqS , eq₂ =
  fieldEv tv eqT (evExactString (subst (λ t → asString tv ≡ just t) (guardEq-sound eq₂) eqS))

------------------------------------------------------------------------
-- Geometries
------------------------------------------------------------------------

geometry-sound : ∀ {v} (ev : GeometryEvidence v) →
                 extractGeometry v ≡ just (extractGeometryFromEvidence ev)
geometry-sound (geometryEv k isObj (fieldEv tv eqT (evExactString eqS)) (fieldEv cv eqC cEv)) =
  trans (bind-just isObj)
  (trans (bind-just eqT)
  (trans (bind-just eqS)
  (trans (bind-just (parseKind-kindName k))
  (trans (bind-just eqC)
         (coordinates-sound k cEv)))))

geometry-complete : ∀ {v g} → extractGeometry v ≡ just g →
                    ∃ λ (ev : GeometryEvidence v) → extractGeometryFromEvidence ev ≡ g
geometry-complete {v} eq
  with bind-just⁻ (asObject v) eq
... | kvs , isObj , eq₁ with bind-just⁻ (lookupField "type" kvs) eq₁
...   | tv , eqT , eq₂ with bind-just⁻ (asString tv) eq₂
...     | tn , eqS , eq₃ with bind-just⁻ (parseKind tn) eq₃
...       | k , eqK , eq₄ with bind-just⁻ (lookupField "coordinates" kvs) eq₄
...         | cv , eqC , eq₅ with coordinates-complete k eq₅
...           | cEv , r =
  geometryEv k isObj
    (fieldEv tv eqT (evExactString (subst (λ t → asString tv ≡ just t) (parseKind-sound eqK) eqS)))
    (fieldEv cv eqC cEv) , r

------------------------------------------------------------------------
-- Features
------------------------------------------------------------------------

feature-sound : ∀ {v} (ev : FeatureEvidence v) →
                extractFeature v ≡ just (extractFeatureFromEvidence ev)
feature-sound (featureEv isObj tyEv geomLookup gEv) =
  trans (bind-just isObj)
  (trans (bind-just (hasType-sound tyEv))
  (trans (bind-just geomLookup)
         (bind-just (geometry-sound gEv))))

feature-complete : ∀ {v f} → extractFeature v ≡ just f →
                   ∃ λ (ev : FeatureEvidence v) → extractFeatureFromEvidence ev ≡ f
feature-complete {v} eq
  with bind-just⁻ (asObject v) eq
... | kvs , isObj , eq₁ with bind-just⁻ (hasType "Feature" kvs) eq₁
...   | _ , eqH , eq₂ with bind-just⁻ (lookupField "geometry" kvs) eq₂
...     | gv , eqG , eq₃ with bind-just⁻ (extractGeometry gv) eq₃
...       | geom , eqX , eq₄ with geometry-complete eqX
...         | gEv , r =
  featureEv isObj (hasType-complete eqH) eqG gEv ,
  trans (cong (featureOf kvs) r) (just-injective eq₄)

------------------------------------------------------------------------
-- Feature collections
------------------------------------------------------------------------

featureCollection-sound : ∀ {v} (ev : FeatureCollectionEvidence v) →
                          extractFeatureCollection v ≡ just (extractFeatureCollectionFromEvidence ev)
featureCollection-sound (featureCollectionEv isObj tyEv featLookup isArr fsEv) =
  trans (bind-just isObj)
  (trans (bind-just (hasType-sound tyEv))
  (trans (bind-just featLookup)
  (trans (bind-just isArr)
  (trans (bind-just (mapM-sound {g = extractFeatureFromEvidence} feature-sound fsEv))
         refl))))

features-complete : ∀ {xs fs} → mapM extractFeature xs ≡ just fs →
                    ∃ λ (fsEv : All FeatureEvidence xs) → extractFeaturesFromEvidence fsEv ≡ fs
features-complete = mapM-complete {P = FeatureEvidence} {f = extractFeature}
                                  {g = extractFeatureFromEvidence} feature-complete

private
  assemble : ∀ {v kvs fv xs fs fc} →
             asObject v ≡ just kvs →
             hasType "FeatureCollection" kvs ≡ just tt →
             lookupField "features" kvs ≡ just fv →
             asArray fv ≡ just xs →
             mapM extractFeature xs ≡ just fs →
             collectionOf kvs fs ≡ fc →
             ∃ λ (ev : FeatureCollectionEvidence v) → extractFeatureCollectionFromEvidence ev ≡ fc
  assemble {kvs = kvs} isObj eqH eqF eqA eqM refl =
    featureCollectionEv isObj (hasType-complete eqH) eqF eqA (proj₁ (features-complete eqM)) ,
    cong (collectionOf kvs) (proj₂ (features-complete eqM))

featureCollection-complete : ∀ {v fc} → extractFeatureCollection v ≡ just fc →
                             ∃ λ (ev : FeatureCollectionEvidence v) →
                               extractFeatureCollectionFromEvidence ev ≡ fc
featureCollection-complete {v} eq
  with bind-just⁻ (asObject v) eq
... | kvs , isObj , eq₁ with bind-just⁻ (hasType "FeatureCollection" kvs) eq₁
...   | _ , eqH , eq₂ with bind-just⁻ (lookupField "features" kvs) eq₂
...     | fv , eqF , eq₃ with bind-just⁻ (asArray fv) eq₃
...       | xs , eqA , eq₄ with bind-just⁻ (mapM extractFeature xs) eq₄
...         | fs , eqM , eq₅ = assemble isObj eqH eqF eqA eqM (just-injective eq₅)
