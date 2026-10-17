{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.XML.Parser where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false; if_then_else_)
open import Data.Char.Base using (Char)
open import Data.Char.Properties using (_≟_)
open import Data.String.Base as String using (String; toList; fromList; _==_)
open import Data.Nat.Base using (ℕ; zero; suc)
open import Data.List.Base as List using (List; []; _∷_; _++_; reverse; length)
open import Data.Product.Base using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe.Base as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Unit.Base using (⊤; tt)
open import Function.Base using (_∘_; _$_)
open import Relation.Nullary.Decidable using (yes; no)

open import GeoAgda.Data.XML.AST
open import GeoAgda.Parsing.Invertible.Char using (isWhitespace)

------------------------------------------------------------------------
-- Whitespace & Character Helpers
------------------------------------------------------------------------

stripLeadingWS : List Char → List Char
stripLeadingWS []       = []
stripLeadingWS (c ∷ cs) with isWhitespace c
... | true  = stripLeadingWS cs
... | false = c ∷ cs

isTagChar : Char → Bool
isTagChar ' '  = false
isTagChar '\t' = false
isTagChar '\n' = false
isTagChar '\r' = false
isTagChar '>'  = false
isTagChar '/'  = false
isTagChar '='  = false
isTagChar _    = true

takeWhileTag : List Char → List Char × List Char
takeWhileTag []       = ([] , [])
takeWhileTag (c ∷ cs) with isTagChar c
... | true  = let (tag , rest) = takeWhileTag cs in (c ∷ tag , rest)
... | false = ([] , c ∷ cs)

------------------------------------------------------------------------
-- Entity Unescaping
------------------------------------------------------------------------

unescapeXMLChars : List Char → List Char
unescapeXMLChars [] = []
unescapeXMLChars ('&' ∷ 'q' ∷ 'u' ∷ 'o' ∷ 't' ∷ ';' ∷ cs) = '"' ∷ unescapeXMLChars cs
unescapeXMLChars ('&' ∷ 'a' ∷ 'm' ∷ 'p' ∷ ';' ∷ cs)       = '&' ∷ unescapeXMLChars cs
unescapeXMLChars ('&' ∷ 'l' ∷ 't' ∷ ';' ∷ cs)             = '<' ∷ unescapeXMLChars cs
unescapeXMLChars ('&' ∷ 'g' ∷ 't' ∷ ';' ∷ cs)             = '>' ∷ unescapeXMLChars cs
unescapeXMLChars (c ∷ cs)                                  = c ∷ unescapeXMLChars cs

------------------------------------------------------------------------
-- Attribute Parsing
------------------------------------------------------------------------

-- Read attribute value until closing '"'
takeAttrValue : List Char → List Char × List Char
takeAttrValue []             = ([] , [])
takeAttrValue ('"' ∷ cs)     = ([] , cs)
takeAttrValue (c ∷ cs)       = let (val , rest) = takeAttrValue cs in (c ∷ val , rest)

-- Parse a single attribute: ` key="val"`
parseSingleAttr : List Char → Maybe (Attribute × List Char)
parseSingleAttr cs with takeWhileTag (stripLeadingWS cs)
... | ([] , _) = nothing
... | (kChars , rest1) with stripLeadingWS rest1
...   | ('=' ∷ '"' ∷ rest2) =
        let (valChars , rest3) = takeAttrValue rest2
            val = fromList (unescapeXMLChars valChars)
        in just ((fromList kChars , val) , rest3)
...   | _ = nothing

parseAttributesLoop : ℕ → List Char → Attributes × List Char
parseAttributesLoop zero cs = ([] , cs)
parseAttributesLoop (suc fuel) cs with parseSingleAttr cs
... | nothing           = ([] , cs)
... | just (attr , rem) =
        let (attrs , finalRem) = parseAttributesLoop fuel rem
        in (attr ∷ attrs , finalRem)

parseAttributes : List Char → Attributes × List Char
parseAttributes cs = parseAttributesLoop (length cs) cs

------------------------------------------------------------------------
-- Recursive XML Tree Parser
------------------------------------------------------------------------

mutual
  parseChildren : ℕ → String → List Char → Maybe (List XMLDoc × List Char)
  parseChildren zero _ _ = nothing
  parseChildren (suc fuel) tag cs with stripLeadingWS cs
  ... | ('<' ∷ '/' ∷ rest) with takeWhileTag rest
    ... | (closeTagChars , rest2) with stripLeadingWS rest2
      ... | ('>' ∷ rest3) =
            if fromList closeTagChars == tag
            then just ([] , rest3)
            else nothing
      ... | _ = nothing
  ... | (c ∷ csRest) with parseElement fuel (c ∷ csRest)
    ... | nothing = nothing
    ... | just (child , rest2) with parseChildren fuel tag rest2
      ... | nothing = nothing
      ... | just (children , rest3) = just (child ∷ children , rest3)
  ... | [] = nothing

  parseElement : ℕ → List Char → Maybe (XMLDoc × List Char)
  parseElement zero _ = nothing
  parseElement (suc fuel) cs with stripLeadingWS cs
  ... | ('<' ∷ rest) with takeWhileTag rest
    ... | ([] , _) = nothing
    ... | (tagChars , rest2) =
          let tag = fromList tagChars
              (attrs , rest3) = parseAttributes rest2
          in case (stripLeadingWS rest3) of λ where
               ('/' ∷ '>' ∷ rest4) →
                 just (leafElement tag attrs , rest4)
               ('>' ∷ rest4) →
                 case (parseChildren fuel tag rest4) of λ where
                   (just (children , rest5)) →
                     just (elementList tag attrs children , rest5)
                   nothing → nothing
               _ → nothing
  ... | (c ∷ csRest) with takeWhileTag (c ∷ csRest)
    ... | ([] , _) = nothing
    ... | (textChars , rest2) =
          just (text (fromList (unescapeXMLChars textChars)) , rest2)
  ... | [] = nothing
  where
    case_of_ : ∀ {A B : Set} → A → (A → B) → B
    case x of f = f x

------------------------------------------------------------------------
-- Top-Level XML Parser
------------------------------------------------------------------------

parseXMLChars : List Char → Maybe XMLDoc
parseXMLChars cs with parseElement (length cs) (stripLeadingWS cs)
... | just (doc , rest) =
      case (stripLeadingWS rest) of λ where
        [] → just doc
        _  → nothing
... | nothing = nothing
  where
    case_of_ : ∀ {A B : Set} → A → (A → B) → B
    case x of f = f x

parseXML : String → Maybe XMLDoc
parseXML = parseXMLChars ∘ toList
