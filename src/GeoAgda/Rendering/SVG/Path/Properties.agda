{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Rendering a `Path` agrees with the string formatters in `PathData`.
--
-- The semantics: rendering is a monoid homomorphism from path concatenation to
-- space-separated concatenation `_⋄_` of strings.
module GeoAgda.Rendering.SVG.Path.Properties where

open import Data.Char using (Char)
open import Data.List using (List; []; _∷_; _++_; map; foldr)
open import Data.List.Properties using (++-assoc; ++-identityʳ)
open import Data.Product using (_,_)
open import Data.Unit using (⊤; tt)
open import Data.Empty using (⊥)
open import Data.Container using (⟦_⟧)
open import Data.Container.FreeMonad using (pure; impure)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; cong; cong₂; trans; sym)

open import GeoAgda.Model.Exact using (fromExactPt)
open import GeoAgda.Rendering.SVG.Path
open import GeoAgda.Rendering.SVG.PathData using (formatPathLines; formatRingD; formatPointPair)
open import GeoAgda.Rendering.SVG.Projection using (Projection)

------------------------------------------------------------------------
-- Space-separated concatenation
------------------------------------------------------------------------

infixr 5 _⋄_
_⋄_ : List Char → List Char → List Char
[]        ⋄ t = t
s@(_ ∷ _) ⋄ t = s ++ sep t

sep-⋄ : ∀ a b → sep (a ⋄ b) ≡ sep a ++ sep b
sep-⋄ []       b = refl
sep-⋄ (x ∷ xs) b = refl

⋄-assoc : ∀ a b c → (a ⋄ b) ⋄ c ≡ a ⋄ (b ⋄ c)
⋄-assoc []           b c = refl
⋄-assoc a@(x ∷ xs)   b c =
  trans (++-assoc a (sep b) (sep c)) (cong (a ++_) (sym (sep-⋄ b c)))

⋄-identityʳ : ∀ a → a ⋄ [] ≡ a
⋄-identityʳ []       = refl
⋄-identityʳ (x ∷ xs) = ++-identityʳ (x ∷ xs)

------------------------------------------------------------------------
-- `finish` does not change the rendering of a fragment
------------------------------------------------------------------------

renderAlg-cong : ∀ proj c (f g : PathPos c → List Char) → (∀ v → f v ≡ g v) →
                 renderAlg proj (c , f) ≡ renderAlg proj (c , g)
renderAlg-cong proj (moveTo x y) f g h = cong (λ s → 'M' ∷ ' ' ∷ point proj x y ++ sep s) (h tt)
renderAlg-cong proj (lineTo x y) f g h = cong (λ s → 'L' ∷ ' ' ∷ point proj x y ++ sep s) (h tt)
renderAlg-cong proj close        f g h = cong (λ s → 'Z' ∷ sep s) (h tt)
renderAlg-cong proj stop         f g h = refl

render-finish : ∀ proj (p : PathM ⊤) → renderPath proj (finish p) ≡ renderM proj p
render-finish proj (pure tt)       = refl
render-finish proj (impure (c , r)) =
  renderAlg-cong proj c _ _ (λ v → render-finish proj (r v))

------------------------------------------------------------------------
-- Rings
------------------------------------------------------------------------

-- A ring as the string `formatRingD` prints.
ringD : Projection → List Pt → List Char
ringD proj r = formatRingD proj (map fromExactPt r)

private
  -- the rest after the first vertex is never empty: it ends in `Z`
  sep-lines : ∀ {A} proj (f : A → List Char) ps (k : PathM A) →
    sep (renderWith proj f (linesK ps (closeK k))) ≡ ' ' ∷ renderWith proj f (linesK ps (closeK k))
  sep-lines proj f []      k = refl
  sep-lines proj f (p ∷ ps) k = refl

lines-≡ : ∀ {A} proj (f : A → List Char) ps (k : PathM A) →
  ' ' ∷ renderWith proj f (linesK ps (closeK k))
    ≡ formatPathLines proj (map fromExactPt ps) ++ (' ' ∷ 'Z' ∷ sep (renderWith proj f k))
lines-≡ proj f []       k = refl
lines-≡ proj f (q ∷ qs) k =
  trans (cong (λ s → ' ' ∷ 'L' ∷ ' ' ∷ Q ++ s) (trans (sep-lines proj f qs k) (lines-≡ proj f qs k)))
        (cong (λ s → ' ' ∷ 'L' ∷ ' ' ∷ s)
              (sym (++-assoc Q (formatPathLines proj (map fromExactPt qs)) (' ' ∷ 'Z' ∷ sep (renderWith proj f k)))))
  where Q = formatPointPair (proj (fromExactPt q))

-- A ring, then the rest `k`: the ring's text and the rest's, space-separated.
ringK-≡ : ∀ {A} proj (f : A → List Char) r (k : PathM A) →
  renderWith proj f (ringK r k) ≡ ringD proj r ⋄ renderWith proj f k
ringK-≡ proj f []       k = refl
ringK-≡ proj f (p ∷ ps) k =
  trans (cong (λ s → 'M' ∷ ' ' ∷ P ++ s) (trans (sep-lines proj f ps k) (lines-≡ proj f ps k)))
        (cong (λ s → 'M' ∷ ' ' ∷ s)
              (trans (cong (P ++_) (sym (++-assoc L (' ' ∷ 'Z' ∷ []) (sep (renderWith proj f k)))))
                     (sym (++-assoc P (L ++ (' ' ∷ 'Z' ∷ [])) (sep (renderWith proj f k))))))
  where
    P = formatPointPair (proj (fromExactPt p))
    L = formatPathLines proj (map fromExactPt ps)

-- A polygon's rings: concatenation of the rings, space-separated.
polygonD : Projection → List (List Pt) → List Char
polygonD proj = foldr (λ r acc → ringD proj r ⋄ acc) []

ringsK-≡ : ∀ {A} proj (f : A → List Char) rs (k : PathM A) →
  renderWith proj f (ringsK rs k) ≡ polygonD proj rs ⋄ renderWith proj f k
ringsK-≡ proj f []       k = refl
ringsK-≡ proj f (r ∷ rs) k =
  trans (ringK-≡ proj f r (ringsK rs k))
    (trans (cong (ringD proj r ⋄_) (ringsK-≡ proj f rs k))
           (sym (⋄-assoc (ringD proj r) (polygonD proj rs) (renderWith proj f k))))

-- The `d` attribute of a polygon, built directly (`polygonP`) or via `finish`.
polygonP-≡ : ∀ proj rs → renderPath proj (polygonP rs) ≡ polygonD proj rs
polygonP-≡ proj rs = trans (ringsK-≡ proj (λ ()) rs stopM) (⋄-identityʳ (polygonD proj rs))

ringP-≡ : ∀ proj r → renderPath proj (ringP r) ≡ ringD proj r
ringP-≡ proj r = trans (ringK-≡ proj (λ ()) r stopM) (⋄-identityʳ (ringD proj r))

polygon-≡ : ∀ proj rs → renderPath proj (finish (polygon rs)) ≡ polygonD proj rs
polygon-≡ proj rs =
  trans (render-finish proj (polygon rs))
    (trans (ringsK-≡ proj (λ _ → []) rs (pure tt)) (⋄-identityʳ (polygonD proj rs)))

ring-≡ : ∀ proj r → renderPath proj (finish (ring r)) ≡ ringD proj r
ring-≡ proj r =
  trans (render-finish proj (ring r))
    (trans (ringK-≡ proj (λ _ → []) r (pure tt)) (⋄-identityʳ (ringD proj r)))
