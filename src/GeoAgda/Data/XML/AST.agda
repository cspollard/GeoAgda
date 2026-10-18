{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Data.XML.AST where

open import Data.String.Base using (String)
open import Data.List.Base using (List; []; _∷_)
open import Data.Product.Base using (_×_; _,_)
open import Data.Unit.Base using (⊤; tt)

------------------------------------------------------------------------
-- XML / SVG AST
------------------------------------------------------------------------

-- XML attributes as key-value pairs
Attribute : Set
Attribute = String × String

Attributes : Set
Attributes = List Attribute

-- Inductive XML tree parameterized over leaf/variable type X
data XML (X : Set) : Set where
  pure        : X → XML X
  text        : String → XML X
  elementList : (tag : String) (attrs : Attributes) (children : List (XML X)) → XML X

-- Standard closed XML document/element
XMLDoc : Set
XMLDoc = XML ⊤

------------------------------------------------------------------------
-- Generic XML Smart Constructors
------------------------------------------------------------------------

leafElement : ∀ {X} (tag : String) (attrs : Attributes) → XML X
leafElement tag attrs = elementList tag attrs []

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
