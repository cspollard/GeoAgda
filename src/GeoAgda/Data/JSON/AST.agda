{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}




module GeoAgda.Data.JSON.AST where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.Integer.Base using (ℤ)
open import Data.Sign.Base using (Sign; +; -)
open import Data.String.Base using (String)
open import Data.List.Base using (List; []; _∷_; length; lookup)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Empty using (⊥)
open import Data.Unit.Base using (⊤; tt)
open import Data.Fin.Base using (Fin; zero; suc)
open import Data.Container.Core public using (Container; _▷_; ⟦_⟧)
open import Data.Container.FreeMonad public using (_⋆_; pure; impure)


------------------------------------------------------------------------
-- JSON Numbers
------------------------------------------------------------------------

-- Exact representation of JSON numbers according to RFC 8259:
--   sign * (integral + fraction * 10^(- length fraction)) * 10^exponent
record JSONNumber : Set where
  constructor jsonNumber
  field
    sign     : Sign
    integral : ℕ
    fraction : List (Fin 10)
    exponent : ℤ

------------------------------------------------------------------------
-- JSON Container Signature
------------------------------------------------------------------------

-- Shapes represent the syntactic node kinds:
-- - Literals: null, boolean, number, string
-- - Compound nodes:
--   * arrayₛ n: an array with n child elements
--   * objectₛ keys: an object with field names given by `keys`
data JSONShape : Set where
  nullₛ   : JSONShape
  boolₛ   : Bool → JSONShape
  numberₛ : JSONNumber → JSONShape
  stringₛ : String → JSONShape
  arrayₛ  : (n : ℕ) → JSONShape
  objectₛ : (keys : List String) → JSONShape

-- Positions identify child branches for each shape:
-- - Literals have no subtrees (Position = ⊥)
-- - arrayₛ n has n positions indexed by `Fin n`
-- - objectₛ keys has `length keys` positions indexed by `Fin (length keys)`
JSONPosition : JSONShape → Set
JSONPosition nullₛ          = ⊥
JSONPosition (boolₛ _)      = ⊥
JSONPosition (numberₛ _)    = ⊥
JSONPosition (stringₛ _)    = ⊥
JSONPosition (arrayₛ n)     = Fin n
JSONPosition (objectₛ keys) = Fin (length keys)

-- The JSON container at universe level 0ℓ
JSONContainer : Container 0ℓ 0ℓ
JSONContainer = JSONShape ▷ JSONPosition

------------------------------------------------------------------------
-- The Free Monad JSON Type
------------------------------------------------------------------------

-- JSON AST parameterized over variable/leaf type X
JSON : Set → Set
JSON X = JSONContainer ⋆ X

-- Standard closed JSON values (with terminal leaf ⊤)
JSONValue : Set
JSONValue = JSON ⊤

------------------------------------------------------------------------
-- Smart Constructors
------------------------------------------------------------------------

null : ∀ {X} → JSON X
null = impure (nullₛ , λ ())

bool : ∀ {X} → Bool → JSON X
bool b = impure (boolₛ b , λ ())

trueⱼ : ∀ {X} → JSON X
trueⱼ = bool true

falseⱼ : ∀ {X} → JSON X
falseⱼ = bool false


number : ∀ {X} → JSONNumber → JSON X
number n = impure (numberₛ n , λ ())

string : ∀ {X} → String → JSON X
string s = impure (stringₛ s , λ ())

array : ∀ {X} (n : ℕ) → (Fin n → JSON X) → JSON X
array n k = impure (arrayₛ n , k)

object : ∀ {X} (keys : List String) → (Fin (length keys) → JSON X) → JSON X
object keys k = impure (objectₛ keys , k)

-- Convert a list of elements to an array node
arrayFromList : ∀ {X} (xs : List (JSON X)) → JSON X
arrayFromList xs = impure (arrayₛ (length xs) , lookup xs)

-- Extract keys from an association list
keysOf : ∀ {X} → List (String × JSON X) → List String
keysOf []             = []
keysOf ((k , _) ∷ xs) = k ∷ keysOf xs

-- Lookup value for the i-th key position definitionally
lookupKeys : ∀ {X} (kvs : List (String × JSON X)) → Fin (length (keysOf kvs)) → JSON X
lookupKeys []             ()
lookupKeys ((_ , v) ∷ _)  zero    = v
lookupKeys ((_ , _) ∷ xs) (suc i) = lookupKeys xs i

-- Convert an association list of (key, value) pairs to an object node
objectFromKVs : ∀ {X} (kvs : List (String × JSON X)) → JSON X
objectFromKVs kvs = impure (objectₛ (keysOf kvs) , lookupKeys kvs)

