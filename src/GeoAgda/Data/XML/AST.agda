{-# OPTIONS --safe --cubical-compatible #-}

module GeoAgda.Data.XML.AST where

open import Level using (0ℓ)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.String.Base using (String)
open import Data.List.Base using (List; []; _∷_; length; lookup)
open import Data.Product.Base using (_×_; _,_)
open import Data.Empty using (⊥)
open import Data.Unit.Base using (⊤; tt)
open import Data.Fin.Base using (Fin; zero; suc)
open import Data.Container.Core using (Container; _▷_; ⟦_⟧)
open import Data.Container.FreeMonad using (_⋆_; pure; impure)

------------------------------------------------------------------------
-- XML / SVG Container Signature
------------------------------------------------------------------------

-- XML attributes as key-value pairs
Attribute : Set
Attribute = String × String

Attributes : Set
Attributes = List Attribute

-- Shapes for XML/SVG AST:
-- - textₛ content: raw character data / text node
-- - elementₛ tag attrs n: element with tag, attributes, and n children
data XMLShape : Set where
  textₛ    : String → XMLShape
  elementₛ : (tag : String) (attrs : Attributes) (n : ℕ) → XMLShape

-- Positions identify child element branches:
-- - textₛ has no children (Position = ⊥)
-- - elementₛ tag attrs n has n children indexed by Fin n
XMLPosition : XMLShape → Set
XMLPosition (textₛ _)         = ⊥
XMLPosition (elementₛ _ _ n)  = Fin n

-- The XML container at level 0ℓ
XMLContainer : Container 0ℓ 0ℓ
XMLContainer = XMLShape ▷ XMLPosition

------------------------------------------------------------------------
-- The Free Monad XML Type
------------------------------------------------------------------------

-- XML tree parameterized over leaf/variable type X
XML : Set → Set
XML X = XMLContainer ⋆ X

-- Standard closed XML document/element
XMLDoc : Set
XMLDoc = XML ⊤

------------------------------------------------------------------------
-- Generic XML Smart Constructors
------------------------------------------------------------------------

text : ∀ {X} → String → XML X
text s = impure (textₛ s , λ ())

element : ∀ {X} (tag : String) (attrs : Attributes) (n : ℕ) → (Fin n → XML X) → XML X
element tag attrs n children = impure (elementₛ tag attrs n , children)

elementList : ∀ {X} (tag : String) (attrs : Attributes) (children : List (XML X)) → XML X
elementList tag attrs children = impure (elementₛ tag attrs (length children) , lookup children)

leafElement : ∀ {X} (tag : String) (attrs : Attributes) → XML X
leafElement tag attrs = impure (elementₛ tag attrs 0 , λ ())

------------------------------------------------------------------------
-- SVG Smart Constructors
------------------------------------------------------------------------

-- Top-level SVG root element with default SVG namespace
svg : ∀ {X} → Attributes → List (XML X) → XML X
svg attrs children = elementList "svg" (("xmlns" , "http://www.w3.org/2000/svg") ∷ attrs) children

-- Grouping container
g : ∀ {X} → Attributes → List (XML X) → XML X
g attrs children = elementList "g" attrs children

-- SVG Path element (<path d="..." ... />)
path : ∀ {X} → (d : String) → Attributes → XML X
path d attrs = leafElement "path" (("d" , d) ∷ attrs)

-- SVG Circle element (<circle cx="..." cy="..." r="..." ... />)
circle : ∀ {X} → (cx cy r : String) → Attributes → XML X
circle cx cy r attrs = leafElement "circle" (("cx" , cx) ∷ ("cy" , cy) ∷ ("r" , r) ∷ attrs)

-- SVG Rect element (<rect x="..." y="..." width="..." height="..." ... />)
rect : ∀ {X} → (x y width height : String) → Attributes → XML X
rect x y w h attrs = leafElement "rect" (("x" , x) ∷ ("y" , y) ∷ ("width" , w) ∷ ("height" , h) ∷ attrs)

-- SVG Polygon element (<polygon points="..." ... />)
polygon : ∀ {X} → (points : String) → Attributes → XML X
polygon pts attrs = leafElement "polygon" (("points" , pts) ∷ attrs)

-- SVG Polyline element (<polyline points="..." ... />)
polyline : ∀ {X} → (points : String) → Attributes → XML X
polyline pts attrs = leafElement "polyline" (("points" , pts) ∷ attrs)
