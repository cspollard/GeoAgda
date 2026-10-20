{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.XML.Parser where

open import Data.Bool using (Bool; true; false)
open import Data.Char using (Char; isSpace)
open import Data.Char.Properties using (_≟_)
open import Data.String as String using (String; toList; fromList)
open import Data.String.Properties using () renaming (_≟_ to _≟S_)
open import Data.Nat using (ℕ; zero; suc)
open import Data.List as List using (List; []; _∷_; _++_; length)
open import Data.Product using (_×_; _,_)
open import Data.Maybe as Maybe using (Maybe; just; nothing)
open import Data.Unit using (⊤; tt)
open import Function using (_∘_)
open import Relation.Nullary.Decidable using (yes; no)

open import Data.XML.AST

------------------------------------------------------------------------
-- Whitespace & Escaped Lexical Scanners
------------------------------------------------------------------------

stripLeadingWS : List Char → List Char
stripLeadingWS []       = []
stripLeadingWS (c ∷ cs) with isSpace c
... | true  = stripLeadingWS cs
... | false = c ∷ cs

lexName : List Char → List Char × List Char
lexName [] = ([] , [])
lexName (c ∷ cs) with c ≟ ' ' | c ≟ '\t' | c ≟ '\n' | c ≟ '\r' | c ≟ '>' | c ≟ '/' | c ≟ '=' | c ≟ '<' | c ≟ '!'
... | yes _ | _     | _     | _     | _     | _     | _     | _     | _     = ([] , c ∷ cs)
... | no  _ | yes _ | _     | _     | _     | _     | _     | _     | _     = ([] , c ∷ cs)
... | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     | _     = ([] , c ∷ cs)
... | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     = ([] , c ∷ cs)
... | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     = ([] , c ∷ cs)
... | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     = ([] , c ∷ cs)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     = ([] , c ∷ cs)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     = ([] , c ∷ cs)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ = ([] , c ∷ cs)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ with c ≟ '\\'
...   | no _ = let (acc , rem) = lexName cs in (c ∷ acc , rem)
lexName (c ∷ [])     | no _ | no _ | no _ | no _ | no _ | no _ | no _ | no _ | no _ | yes _ = ([] , [])
lexName (c ∷ d ∷ cs) | no _ | no _ | no _ | no _ | no _ | no _ | no _ | no _ | no _ | yes _
  with d ≟ '0' | d ≟ '\\' | d ≟ 's' | d ≟ 't' | d ≟ 'n' | d ≟ 'r' | d ≟ 'g' | d ≟ 'f' | d ≟ 'e' | d ≟ 'l' | d ≟ 'b'
... | yes _ | _     | _     | _     | _     | _     | _     | _     | _     | _     | _     = let (acc , rem) = lexName cs in (acc , rem)
... | no  _ | yes _ | _     | _     | _     | _     | _     | _     | _     | _     | _     = let (acc , rem) = lexName cs in ('\\' ∷ acc , rem)
... | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     | _     | _     | _     = let (acc , rem) = lexName cs in (' '  ∷ acc , rem)
... | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     | _     | _     = let (acc , rem) = lexName cs in ('\t' ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     | _     = let (acc , rem) = lexName cs in ('\n' ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     = let (acc , rem) = lexName cs in ('\r' ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     = let (acc , rem) = lexName cs in ('>'  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     = let (acc , rem) = lexName cs in ('/'  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     = let (acc , rem) = lexName cs in ('='  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     = let (acc , rem) = lexName cs in ('<'  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ = let (acc , rem) = lexName cs in ('!'  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ = let (acc , rem) = lexName cs in (d    ∷ acc , rem)

lexAttrValue : List Char → Maybe (List Char × List Char)
lexAttrValue [] = nothing
lexAttrValue (c ∷ cs) with c ≟ '"'
... | yes _ = just ([] , cs)
... | no  _ with c ≟ '\\'
...   | no _ with lexAttrValue cs
...     | nothing          = nothing
...     | just (acc , rem) = just (c ∷ acc , rem)
lexAttrValue (c ∷ [])     | no _ | yes _ = nothing
lexAttrValue (c ∷ d ∷ cs) | no _ | yes _ with d ≟ '\\' | d ≟ '"' | d ≟ 'l' | d ≟ 'g' | d ≟ 'a'
... | yes _ | _     | _     | _     | _ with lexAttrValue cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('\\' ∷ acc , rem)
lexAttrValue (c ∷ d ∷ cs) | no _ | yes _ | no _ | yes _ | _     | _     | _ with lexAttrValue cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('"' ∷ acc , rem)
lexAttrValue (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | yes _ | _     | _ with lexAttrValue cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('<' ∷ acc , rem)
lexAttrValue (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | no  _ | yes _ | _ with lexAttrValue cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('>' ∷ acc , rem)
lexAttrValue (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | no  _ | no  _ | yes _ with lexAttrValue cs
...   | nothing          = nothing
...   | just (acc , rem) = just ('&' ∷ acc , rem)
lexAttrValue (c ∷ d ∷ cs) | no _ | yes _ | no _ | no  _ | no  _ | no  _ | no  _ = nothing

lexText : List Char → List Char × List Char
lexText [] = ([] , [])
lexText (c ∷ cs) with c ≟ '<' | c ≟ '>'
... | yes _ | _     = ([] , c ∷ cs)
... | no  _ | yes _ = ([] , c ∷ cs)
... | no  _ | no  _ with c ≟ '\\'
...   | no _ = let (acc , rem) = lexText cs in (c ∷ acc , rem)
lexText (c ∷ [])     | no _ | no _ | yes _ = ([] , [])
lexText (c ∷ d ∷ cs) | no _ | no _ | yes _ with d ≟ 'e' | d ≟ '\\' | d ≟ 'l' | d ≟ 'g' | d ≟ 'a' | d ≟ 's' | d ≟ 't' | d ≟ 'n' | d ≟ 'r'
... | yes _ | _     | _     | _     | _     | _     | _     | _     | _     = ([] , cs)
... | no  _ | yes _ | _     | _     | _     | _     | _     | _     | _     = let (acc , rem) = lexText cs in ('\\' ∷ acc , rem)
... | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     | _     = let (acc , rem) = lexText cs in ('<'  ∷ acc , rem)
... | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     | _     = let (acc , rem) = lexText cs in ('>'  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     | _     = let (acc , rem) = lexText cs in ('&'  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     | _     = let (acc , rem) = lexText cs in (' '  ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     | _     = let (acc , rem) = lexText cs in ('\t' ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ | _     = let (acc , rem) = lexText cs in ('\n' ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | yes _ = let (acc , rem) = lexText cs in ('\r' ∷ acc , rem)
... | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ | no  _ = let (acc , rem) = lexText cs in (d    ∷ acc , rem)

------------------------------------------------------------------------
-- Attribute Parsing
------------------------------------------------------------------------

-- Parse a single attribute: ` key="val"`
parseSingleAttr : List Char → Maybe (Attribute × List Char)
parseSingleAttr cs with lexName (stripLeadingWS cs)
... | (kChars , '=' ∷ '"' ∷ rest2) with lexAttrValue rest2
...   | just (valChars , rest3) = just ((fromList kChars , fromList valChars) , rest3)
...   | nothing                 = nothing
parseSingleAttr cs | (_ , _) = nothing

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
-- XML Tokenization
------------------------------------------------------------------------

data XMLToken : Set where
  emptyTok : XMLToken
  textTok  : String → XMLToken
  openTok  : String → Attributes → Bool → XMLToken
  closeTok : String → XMLToken

lexOpenTag : List Char → Maybe (XMLToken × List Char)
lexOpenTag cs with lexName cs
... | (tagChars , rest2) with parseAttributes rest2
...   | (attrs , rest3) with stripLeadingWS rest3
...     | ('/' ∷ '>' ∷ rest4) = just (openTok (fromList tagChars) attrs true , rest4)
...     | ('>' ∷ rest4)       = just (openTok (fromList tagChars) attrs false , rest4)
...     | _                   = nothing

lexCloseTag : List Char → Maybe (XMLToken × List Char)
lexCloseTag cs with lexName cs
... | (closeTagChars , rest2) with stripLeadingWS rest2
...   | ('>' ∷ rest3) = just (closeTok (fromList closeTagChars) , rest3)
...   | _             = nothing

lexXMLToken : List Char → Maybe (XMLToken × List Char)
lexXMLToken [] = nothing
lexXMLToken (c ∷ cs) with c ≟ '<'
... | no _ =
      let (textChars , rest2) = lexText (c ∷ cs)
      in just (textTok (fromList textChars) , rest2)
lexXMLToken (_ ∷ []) | yes _ = nothing
lexXMLToken (_ ∷ d ∷ cs) | yes _ with d ≟ '!' | d ≟ '/'
... | yes _ | _     with cs
...   | ('>' ∷ rest) = just (emptyTok , rest)
...   | _            = nothing
lexXMLToken (_ ∷ d ∷ cs) | yes _ | no _ | yes _ = lexCloseTag cs
lexXMLToken (_ ∷ d ∷ cs) | yes _ | no _ | no  _ = lexOpenTag (d ∷ cs)

tokenizeXMLLoop : ℕ → List Char → Maybe (List XMLToken)
tokenizeXMLLoop zero _ = nothing
tokenizeXMLLoop (suc fuel) cs with stripLeadingWS cs
... | [] = just []
... | c ∷ rest with lexXMLToken (c ∷ rest)
...   | nothing          = nothing
...   | just (tok , rem) = Maybe.map (tok ∷_) (tokenizeXMLLoop fuel rem)

tokenizeXML : List Char → Maybe (List XMLToken)
tokenizeXML cs = tokenizeXMLLoop (suc (length cs)) cs

------------------------------------------------------------------------
-- Recursive-Descent XML Token Parser
------------------------------------------------------------------------

double : ℕ → ℕ
double zero    = zero
double (suc n) = suc (suc (double n))

mutual
  parseXMLTok : ℕ → List XMLToken → Maybe (XMLDoc × List XMLToken)
  parseXMLTok zero _ = nothing
  parseXMLTok (suc fuel) (emptyTok ∷ rest)               = nothing
  parseXMLTok (suc fuel) (textTok s ∷ rest)              = just (text s , rest)
  parseXMLTok (suc fuel) (openTok tag attrs true ∷ rest) = just (elementList tag attrs [] , rest)
  parseXMLTok (suc fuel) (openTok tag attrs false ∷ rest) with parseXMLChildrenTok fuel tag rest
  ... | nothing               = nothing
  ... | just (children , rem) = just (elementList tag attrs children , rem)
  parseXMLTok (suc fuel) _ = nothing

  continueXMLChildren : ℕ → String → XMLDoc → List XMLToken → Maybe (List XMLDoc × List XMLToken)
  continueXMLChildren fuel tag child rem with parseXMLChildrenTok fuel tag rem
  ... | nothing               = nothing
  ... | just (children , rem') = just (child ∷ children , rem')

  parseXMLChildrenTok : ℕ → String → List XMLToken → Maybe (List XMLDoc × List XMLToken)
  parseXMLChildrenTok zero _ _ = nothing
  parseXMLChildrenTok (suc fuel) _   [] = nothing
  parseXMLChildrenTok (suc fuel) tag (closeTok closeTag ∷ rest) with closeTag ≟S tag
  ... | yes _ = just ([] , rest)
  ... | no  _ = nothing
  parseXMLChildrenTok (suc fuel) tag toks with parseXMLTok fuel toks
  ... | nothing            = nothing
  ... | just (child , rem) = continueXMLChildren fuel tag child rem

------------------------------------------------------------------------
-- Top-Level XML Parser
------------------------------------------------------------------------

parseXMLChars : List Char → Maybe XMLDoc
parseXMLChars cs with tokenizeXML cs
... | nothing   = nothing
... | just toks with parseXMLTok (double (length toks)) toks
...   | just (doc , []) = just doc
...   | _               = nothing

parseXML : String → Maybe XMLDoc
parseXML = parseXMLChars ∘ toList
