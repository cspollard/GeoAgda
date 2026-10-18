{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}
module GeoAgda.Parsing.XML.Soundness where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Nat.Base using (ℕ; zero; suc; _+_)
open import Data.String.Base using (String)
open import Data.List.Base as List using (List; []; _∷_; _++_; length; lookup)
open import Data.Product.Base using (_×_; _,_)
open import Data.Unit.Base using (⊤; tt)
open import Data.Empty using (⊥)
open import Data.Container.Core using (Container; _▷_; ⟦_⟧)
open import Data.Container.FreeMonad as Free using (_⋆_; pure; impure; foldr; _>>=_)
open import Function.Base using (_∘_)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; cong)

Attribute : Set
Attribute = String × String

Attributes : Set
Attributes = List Attribute

data XMLShape : Set where
  textₛ    : String → XMLShape
  elementₛ : (tag : String) (attrs : Attributes) (isEmpty : Bool) → XMLShape
  closeₛ   : (tag : String) → XMLShape

XMLPosition : XMLShape → Set
XMLPosition _ = ⊤

XMLContainer : Container 0ℓ 0ℓ
XMLContainer = XMLShape ▷ XMLPosition

XML : Set → Set
XML X = XMLContainer ⋆ (⊤ ⊎ X)
  where open import Data.Sum.Base using (_⊎_; inj₁; inj₂)

XMLDoc : Set
XMLDoc = XMLContainer ⋆ ⊤
