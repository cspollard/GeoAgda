{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Paths as a free monad over drawing commands; see plans/PathPlan.md.
--
-- A `PathM A` is a path fragment that continues into `A`; a complete `Path = PathM ⊥`
-- has been explicitly `stop`ped.  Coordinates are exact scaled integers
-- (`GeoAgda.Model.Exact`).  Rendering is in `GeoAgda.Rendering.SVG.Path`.
module GeoAgda.Model.Path where

open import Level using (0ℓ)
open import Data.Empty using (⊥)
open import Data.List using (List; []; _∷_; reverse)
open import Data.Product using (_×_; _,_)
open import Data.Unit using (⊤; tt)
open import Data.Container using (Container; ⟦_⟧; _▷_)
open import Data.Container.FreeMonad using (_⋆_; pure; impure)
import Data.Container.FreeMonad as FM
open import Data.Integer using (ℤ; ∣_∣)
open import Data.Nat using (ℕ) renaming (_+_ to _+ℕ_)

-- A point: exact scaled coordinates (lon , lat), see `GeoAgda.Model.Exact`.
Pt : Set
Pt = ℤ × ℤ

------------------------------------------------------------------------
-- The container
------------------------------------------------------------------------

data PathShape : Set where
  moveTo lineTo : ℤ → ℤ → PathShape
  close stop    : PathShape

-- One position (the rest of the path) per command, none after `stop`.
PathPos : PathShape → Set
PathPos stop = ⊥
PathPos _    = ⊤

PathC : Container 0ℓ 0ℓ
PathC = PathShape ▷ PathPos

PathM : Set → Set
PathM A = PathC ⋆ A

-- A complete path: explicitly stopped, so it has no leaves.
Path : Set
Path = PathM ⊥

------------------------------------------------------------------------
-- Constructors (continuation style: `cmd … k` is the command, then `k`)
------------------------------------------------------------------------

moveToK lineToK : ∀ {A} → Pt → PathM A → PathM A
moveToK (x , y) k = impure (moveTo x y , λ _ → k)
lineToK (x , y) k = impure (lineTo x y , λ _ → k)

closeK : ∀ {A} → PathM A → PathM A
closeK k = impure (close , λ _ → k)

stopM : ∀ {A} → PathM A
stopM = impure (stop , λ ())

-- Concatenation, `>>=` of the free monad.
_>>_ : ∀ {A B} → PathM A → PathM B → PathM B
p >> q = p FM.>>= λ _ → q

-- Make a fragment complete.
finish : PathM ⊤ → Path
finish p = p FM.>>= λ _ → stopM

------------------------------------------------------------------------
-- From points
------------------------------------------------------------------------

-- The segments after the first vertex.
linesK : ∀ {A} → List Pt → PathM A → PathM A
linesK []       k = k
linesK (p ∷ ps) k = lineToK p (linesK ps k)

-- A closed ring `M p₀ L p₁ … Z`; the empty ring is no commands.
ringK : ∀ {A} → List Pt → PathM A → PathM A
ringK []       k = k
ringK (p ∷ ps) k = moveToK p (linesK ps (closeK k))

ringsK : ∀ {A} → List (List Pt) → PathM A → PathM A
ringsK []       k = k
ringsK (r ∷ rs) k = ringK r (ringsK rs k)

ring : List Pt → PathM ⊤
ring r = ringK r (pure tt)

polygon : List (List Pt) → PathM ⊤
polygon rs = ringsK rs (pure tt)

-- Complete paths, built with the `stop` continuation directly.  (`finish (polygon rs)` is the same
-- path, but `_>>=_` rebuilds every node lazily, keeping both copies alive: do not use it on large data.)
ringP : List Pt → Path
ringP r = ringK r stopM

polygonP : List (List Pt) → Path
polygonP rs = ringsK rs stopM


------------------------------------------------------------------------
-- Reading a path back as rings
------------------------------------------------------------------------

-- The rings (`moveTo`, then the `lineTo`s up to the next `moveTo`, `close` or the end).
pathRings : ∀ {A} → PathM A → List (List Pt)
pathRings = go []
  where
    flush : List Pt → List (List Pt) → List (List Pt)
    flush []        rest = rest
    flush cur@(_ ∷ _) rest = reverse cur ∷ rest

    go : ∀ {A} → List Pt → PathM A → List (List Pt)
    go cur (pure _)                    = flush cur []
    go cur (impure (moveTo x y , r))   = flush cur (go ((x , y) ∷ []) (r tt))
    go cur (impure (lineTo x y , r))   = go ((x , y) ∷ cur) (r tt)
    go cur (impure (close , r))        = flush cur (go [] (r tt))
    go cur (impure (stop , r))         = flush cur []

-- A number that depends on every coordinate, so that printing it forces the path (and
-- lets whatever it was built from be collected).
pathWeight : ∀ {A} → PathM A → ℕ
pathWeight (pure _)                  = 0
pathWeight (impure (moveTo x y , r)) = 1 +ℕ ∣ x ∣ +ℕ ∣ y ∣ +ℕ pathWeight (r tt)
pathWeight (impure (lineTo x y , r)) = 1 +ℕ ∣ x ∣ +ℕ ∣ y ∣ +ℕ pathWeight (r tt)
pathWeight (impure (close , r))      = 1 +ℕ pathWeight (r tt)
pathWeight (impure (stop , r))       = 0
