{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Data.JSON.Conformance where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.String.Base as String using (String)
open import Data.String.Properties using (_≟_)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.List.Base as List using (List; []; _∷_; map)
open import Data.List.Relation.Unary.All as All using (All; []; _∷_)
open import Data.Product.Base using (_×_; _,_; ∃; ∃₂; proj₁; proj₂)
open import Data.Maybe.Base as Maybe using (Maybe; just; nothing)
open import Data.Maybe.Properties using (just-injective)
open import Data.Unit.Base using (⊤; tt)
open import Data.Empty using (⊥; ⊥-elim)
open import Data.Fin.Base using (Fin; zero; suc)
open import Relation.Nullary.Decidable using (Dec; yes; no)
open import Relation.Nullary.Negation using (¬_)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; sym; trans; cong)

open import GeoAgda.Data.JSON.AST
open import GeoAgda.Data.JSON.Schema using (asNumber; asString; asArray; asObject; lookupField)

------------------------------------------------------------------------
-- Rich Schema Language
------------------------------------------------------------------------

data Schema : Set where
  sAny         : Schema
  sNull        : Schema
  sBool        : Schema
  sNumber      : Schema
  sString      : Schema
  sExactString : String → Schema
  sList        : Schema → Schema
  sTuple2      : Schema → Schema → Schema
  sObjectReq   : List (String × Schema) → Schema

------------------------------------------------------------------------
-- Constructive Schema Evidence Relations
------------------------------------------------------------------------

mutual
  data _⊨_ : JSONValue → Schema → Set where
    evAny         : ∀ {v} → v ⊨ sAny

    evNull        : ∀ {v rec} →
                    v ≡ impure (nullₛ , rec) →
                    v ⊨ sNull

    evBool        : ∀ {v rec} (b : Bool) →
                    v ≡ impure (boolₛ b , rec) →
                    v ⊨ sBool

    evNumber      : ∀ {v rec} (n : JSONNumber) →
                    v ≡ impure (numberₛ n , rec) →
                    v ⊨ sNumber

    evString      : ∀ {v rec} (s : String) →
                    v ≡ impure (stringₛ s , rec) →
                    v ⊨ sString

    evExactString : ∀ {v rec expected} →
                    v ≡ impure (stringₛ expected , rec) →
                    v ⊨ sExactString expected

    evList        : ∀ {v xs elemS} →
                    asArray v ≡ just xs →
                    All (_⊨ elemS) xs →
                    v ⊨ sList elemS

    evTuple2      : ∀ {v x₁ x₂ s₁ s₂} →
                    asArray v ≡ just (x₁ ∷ x₂ ∷ []) →
                    x₁ ⊨ s₁ →
                    x₂ ⊨ s₂ →
                    v ⊨ sTuple2 s₁ s₂

    evObject      : ∀ {v kvs reqs} →
                    asObject v ≡ just kvs →
                    AllFieldsEvidence kvs reqs →
                    v ⊨ sObjectReq reqs

  data FieldEvidence (kvs : List (String × JSONValue)) (k : String) (s : Schema) : Set where
    fieldEv : (val : JSONValue) →
              lookupField k kvs ≡ just val →
              val ⊨ s →
              FieldEvidence kvs k s

  data AllFieldsEvidence (kvs : List (String × JSONValue)) : List (String × Schema) → Set where
    nilFields  : AllFieldsEvidence kvs []
    consFields : ∀ {k s reqs} →
                 FieldEvidence kvs k s →
                 AllFieldsEvidence kvs reqs →
                 AllFieldsEvidence kvs ((k , s) ∷ reqs)

------------------------------------------------------------------------
-- Evidence Projections
------------------------------------------------------------------------

extractNumberEvidence : ∀ {v} → v ⊨ sNumber → JSONNumber
extractNumberEvidence (evNumber n _) = n

extractStringEvidence : ∀ {v} → v ⊨ sString → String
extractStringEvidence (evString s _) = s

extractExactStringEvidence : ∀ {v expected} → v ⊨ sExactString expected → String
extractExactStringEvidence {expected = expected} _ = expected

------------------------------------------------------------------------
-- Decidable Verification Combinators
------------------------------------------------------------------------

decNumber : (v : JSONValue) → Dec (v ⊨ sNumber)
decNumber (impure (numberₛ n , rec)) = yes (evNumber n refl)
decNumber (impure (nullₛ     , _))   = no (λ where (evNumber _ ()))
decNumber (impure (boolₛ _   , _))   = no (λ where (evNumber _ ()))
decNumber (impure (stringₛ _ , _))   = no (λ where (evNumber _ ()))
decNumber (impure (arrayₛ _  , _))   = no (λ where (evNumber _ ()))
decNumber (impure (objectₛ _ , _))   = no (λ where (evNumber _ ()))
decNumber (pure _)                   = no (λ where (evNumber _ ()))

decString : (v : JSONValue) → Dec (v ⊨ sString)
decString (impure (stringₛ s , rec)) = yes (evString s refl)
decString (impure (nullₛ     , _))   = no (λ where (evString _ ()))
decString (impure (boolₛ _   , _))   = no (λ where (evString _ ()))
decString (impure (numberₛ _ , _))   = no (λ where (evString _ ()))
decString (impure (arrayₛ _  , _))   = no (λ where (evString _ ()))
decString (impure (objectₛ _ , _))   = no (λ where (evString _ ()))
decString (pure _)                   = no (λ where (evString _ ()))

decExactString : (expected : String) → (v : JSONValue) → Dec (v ⊨ sExactString expected)
decExactString expected (impure (stringₛ s , rec)) with s ≟ expected
... | yes refl = yes (evExactString refl)
... | no  ¬eq  = no (λ where (evExactString refl) → ¬eq refl)
decExactString expected (impure (nullₛ     , _)) = no (λ where (evExactString ()))
decExactString expected (impure (boolₛ _   , _)) = no (λ where (evExactString ()))
decExactString expected (impure (numberₛ _ , _)) = no (λ where (evExactString ()))
decExactString expected (impure (arrayₛ _  , _)) = no (λ where (evExactString ()))
decExactString expected (impure (objectₛ _ , _)) = no (λ where (evExactString ()))
decExactString expected (pure _)                 = no (λ where (evExactString ()))

decTuple2 : ∀ {s₁ s₂} →
            ((v : JSONValue) → Dec (v ⊨ s₁)) →
            ((v : JSONValue) → Dec (v ⊨ s₂)) →
            (v : JSONValue) → Dec (v ⊨ sTuple2 s₁ s₂)
decTuple2 check₁ check₂ v with asArray v in eqArr
... | nothing                      = no (λ where (evTuple2 eq _ _) → contradiction eq (λ ()))
  where
    open import Relation.Nullary.Negation using (contradiction)
... | just []                      = no (λ where (evTuple2 eq _ _) → contradiction eq λ ())
  where
    open import Relation.Nullary.Negation using (contradiction)
... | just (_ ∷ [])                = no (λ where (evTuple2 eq _ _) → contradiction eq λ ())
  where
    open import Relation.Nullary.Negation using (contradiction)
... | just (_ ∷ _ ∷ _ ∷ _)        = no (λ where (evTuple2 eq _ _) → contradiction eq λ ())
  where
    open import Relation.Nullary.Negation using (contradiction)
... | just (x₁ ∷ x₂ ∷ []) with check₁ x₁
...   | no  ¬p₁ = no (λ where (evTuple2 _ p₁ _) → ¬p₁ p₁)
...   | yes p₁  with check₂ x₂
...     | no  ¬p₂ = no (λ where (evTuple2 _ _ p₂) → ¬p₂ p₂)
...     | yes p₂  = yes (evTuple2 eqArr p₁ p₂)

decField : ∀ {s} →
           ((v : JSONValue) → Dec (v ⊨ s)) →
           (k : String) →
           (kvs : List (String × JSONValue)) →
           Dec (FieldEvidence kvs k s)
decField check k kvs with lookupField k kvs in eqLook
... | nothing  = no (λ where (fieldEv _ eq _) → contradiction eq λ ())
  where open import Relation.Nullary.Negation using (contradiction)
... | just val with check val
...   | yes p = yes (fieldEv val eqLook p)
...   | no ¬p = no (λ where (fieldEv .val refl p) → ¬p p)

decList : ∀ {elemS} →
          ((v : JSONValue) → Dec (v ⊨ elemS)) →
          (v : JSONValue) → Dec (v ⊨ sList elemS)
decList checkElem v with asArray v in eqArr
... | nothing   = no (λ where (evList eq _) → contradiction eq λ ())
  where open import Relation.Nullary.Negation using (contradiction)
... | just xs with All.all? checkElem xs
...   | yes allP = yes (evList eqArr allP)
...   | no ¬allP = no (λ where (evList eq allP) → ¬allP allP)

------------------------------------------------------------------------
-- Universe Interpretation of Schemas
------------------------------------------------------------------------

⟦_⟧ : Schema → Set
⟦ sAny ⟧                        = JSONValue
⟦ sNull ⟧                       = ⊤
⟦ sBool ⟧                       = Bool
⟦ sNumber ⟧                     = JSONNumber
⟦ sString ⟧                     = String
⟦ sExactString _ ⟧              = ⊤
⟦ sList s ⟧                     = List ⟦ s ⟧
⟦ sTuple2 s₁ s₂ ⟧               = ⟦ s₁ ⟧ × ⟦ s₂ ⟧
⟦ sObjectReq [] ⟧               = ⊤
⟦ sObjectReq ((k , s) ∷ reqs) ⟧ = ⟦ s ⟧ × ⟦ sObjectReq reqs ⟧

------------------------------------------------------------------------
-- Total Projection / Shortcuts from Conformance Evidence
------------------------------------------------------------------------

mutual
  decodeFromEvidence : ∀ {v s} → v ⊨ s → ⟦ s ⟧
  decodeFromEvidence evAny                        = _
  decodeFromEvidence (evNull _)                   = tt
  decodeFromEvidence (evBool b _)                 = b
  decodeFromEvidence (evNumber n _)               = n
  decodeFromEvidence (evString s _)               = s
  decodeFromEvidence (evExactString _)            = tt
  decodeFromEvidence (evList _ allP)              = decodeList allP
  decodeFromEvidence (evTuple2 _ p₁ p₂)           = decodeFromEvidence p₁ , decodeFromEvidence p₂
  decodeFromEvidence (evObject _ flds)            = decodeFields flds

  decodeList : ∀ {elemS xs} → All (_⊨ elemS) xs → List ⟦ elemS ⟧
  decodeList []         = []
  decodeList (px ∷ pxs) = decodeFromEvidence px ∷ decodeList pxs

  decodeFields : ∀ {kvs reqs} → AllFieldsEvidence kvs reqs → ⟦ sObjectReq reqs ⟧
  decodeFields nilFields                        = tt
  decodeFields (consFields (fieldEv _ _ p) rest) = decodeFromEvidence p , decodeFields rest

