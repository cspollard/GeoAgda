{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Parsing.JSON.Soundness where

open import Level using (0ℓ)
open import Data.Bool.Base using (Bool; true; false)
open import Data.Nat.Base using (ℕ; zero; suc; _+_)
open import Data.Nat.Properties using (+-comm; +-assoc)
open import Data.Char.Base using (Char)
open import Data.Char.Properties using (_≟_)
open import Data.Sign.Base using (Sign; +; -)
open import Data.Fin.Base using (Fin)
open import Data.List.Base using (List; []; _∷_; _++_; length)
open import Data.List.Properties using (++-assoc; ++-identityʳ; length-++)
open import Data.Product.Base using (∃; _×_; _,_; proj₁; proj₂)
open import Data.Maybe.Base as Maybe using (Maybe; just; nothing)
open import Data.String.Base using (String; toList; fromList)
open import Agda.Builtin.String.Properties using (primStringToListInv)
open import Data.Unit.Base using (⊤; tt)
open import Data.Empty using (⊥; ⊥-elim)
open import Function.Bundles using (LeftInverse; _↩_; mk↩)
open import Relation.Nullary.Decidable using (yes; no)
open import Relation.Nullary.Negation using (contradiction)
open import Relation.Binary.PropositionalEquality as ≡
  using (_≡_; refl; sym; trans; cong; module ≡-Reasoning)

open import GeoAgda.Data.JSON.AST
  using (JSON; JSON; JSONNumber; jsonNumber; pure; null; bool; trueⱼ; falseⱼ; number; string; arrayFromList; objectFromList)
open import GeoAgda.Data.JSON.Print
  using (escapeString; printStringLiteral; printJSON; printArrayBody; printObjectBody;
         printNumber; printSign; printNat; printFraction; printExponent)
open import GeoAgda.Parsing.Invertible.Char using (parseDigit; printDigit; parsePrintDigit)
open import GeoAgda.Parsing.Invertible.Number
  using (printDigits; natToDigits; natToDigits-nonEmpty; digitsToNat-natToDigits; NonEmptyList;
         lexNumber; NoLeadingDigit; NoLeadingDot; NoLeadingExp; NoLeadingNumCont; correctLexNumberSign)
open import GeoAgda.Parsing.JSON.Lexer
  using (JSONToken; lbraceT; rbraceT; lbracketT; rbracketT; colonT; commaT; nullT; boolT; numberT; stringT;
         isWhitespace; stripLeadingWhitespace; lexStringChars; lexToken; tokenizeLoop; tokenize)
open import GeoAgda.Parsing.JSON.Parser
  using (parseValue; continueArray; parseArrayElements; continueObject; parseObjectEntries; parseJSON)

------------------------------------------------------------------------
-- 1. Token Stream Representation & Equivalence with printJSON
------------------------------------------------------------------------

printToken : JSONToken → List Char
printToken lbraceT       = '{' ∷ []
printToken rbraceT       = '}' ∷ []
printToken lbracketT     = '[' ∷ []
printToken rbracketT     = ']' ∷ []
printToken colonT        = ':' ∷ []
printToken commaT        = ',' ∷ []
printToken nullT         = 'n' ∷ 'u' ∷ 'l' ∷ 'l' ∷ []
printToken (boolT true)  = 't' ∷ 'r' ∷ 'u' ∷ 'e' ∷ []
printToken (boolT false) = 'f' ∷ 'a' ∷ 'l' ∷ 's' ∷ 'e' ∷ []
printToken (numberT n)   = printNumber n
printToken (stringT s)   = printStringLiteral s

printTokenList : List JSONToken → List Char
printTokenList []       = []
printTokenList (t ∷ ts) = printToken t ++ printTokenList ts

printTokenList-++ : ∀ (xs ys : List JSONToken) →
  printTokenList (xs ++ ys) ≡ printTokenList xs ++ printTokenList ys
printTokenList-++ []       ys = refl
printTokenList-++ (t ∷ xs) ys = begin
  printToken t ++ printTokenList (xs ++ ys)
    ≡⟨ cong (printToken t ++_) (printTokenList-++ xs ys) ⟩
  printToken t ++ (printTokenList xs ++ printTokenList ys)
    ≡⟨ sym (++-assoc (printToken t) (printTokenList xs) (printTokenList ys)) ⟩
  (printToken t ++ printTokenList xs) ++ printTokenList ys
  ∎
  where open ≡-Reasoning

mutual
  printTokens : JSON → List JSONToken
  printTokens (pure tt)           = nullT ∷ []
  printTokens (bool b)            = boolT b ∷ []
  printTokens (number n)          = numberT n ∷ []
  printTokens (string s)          = stringT s ∷ []
  printTokens (arrayFromList xs)  = lbracketT ∷ printArrayTokens xs
  printTokens (objectFromlist kvs) = lbraceT ∷ printObjectTokens kvs

  printArrayTokens : List JSON → List JSONToken
  printArrayTokens []             = rbracketT ∷ []
  printArrayTokens (v ∷ [])       = printTokens v ++ (rbracketT ∷ [])
  printArrayTokens (v ∷ v₂ ∷ vs)  = printTokens v ++ (commaT ∷ printArrayTokens (v₂ ∷ vs))

  printObjectTokens : List (String × JSON) → List JSONToken
  printObjectTokens []                     = rbraceT ∷ []
  printObjectTokens ((k , v) ∷ [])         = stringT k ∷ colonT ∷ printTokens v ++ (rbraceT ∷ [])
  printObjectTokens ((k , v) ∷ kv₂ ∷ kvs)  = stringT k ∷ colonT ∷ printTokens v ++ (commaT ∷ printObjectTokens (kv₂ ∷ kvs))

mutual
  printJSON-tokens : ∀ (v : JSON) → printJSON v ≡ printTokenList (printTokens v)
  printJSON-tokens (pure tt)    = refl
  printJSON-tokens (bool true)  = refl
  printJSON-tokens (bool false) = refl
  printJSON-tokens (number n)   = sym (++-identityʳ (printNumber n))
  printJSON-tokens (string s)   = sym (++-identityʳ (printStringLiteral s))
  printJSON-tokens (arrayFromList xs)  = cong ('[' ∷_) (printArrayBody-tokens xs)
  printJSON-tokens (objectFromlist kvs) = cong ('{' ∷_) (printObjectBody-tokens kvs)

  printArrayBody-tokens : ∀ (xs : List JSON) → printArrayBody xs ≡ printTokenList (printArrayTokens xs)
  printArrayBody-tokens [] = refl
  printArrayBody-tokens (v ∷ []) = begin
    printJSON v ++ (']' ∷ [])
      ≡⟨ cong (_++ (']' ∷ [])) (printJSON-tokens v) ⟩
    printTokenList (printTokens v) ++ printTokenList (rbracketT ∷ [])
      ≡⟨ sym (printTokenList-++ (printTokens v) (rbracketT ∷ [])) ⟩
    printTokenList (printTokens v ++ (rbracketT ∷ []))
    ∎
    where open ≡-Reasoning
  printArrayBody-tokens (v ∷ v₂ ∷ vs) = begin
    printJSON v ++ (',' ∷ printArrayBody (v₂ ∷ vs))
      ≡⟨ cong (_++ (',' ∷ printArrayBody (v₂ ∷ vs))) (printJSON-tokens v) ⟩
    printTokenList (printTokens v) ++ (',' ∷ printArrayBody (v₂ ∷ vs))
      ≡⟨ cong (λ r → printTokenList (printTokens v) ++ (',' ∷ r)) (printArrayBody-tokens (v₂ ∷ vs)) ⟩
    printTokenList (printTokens v) ++ printTokenList (commaT ∷ printArrayTokens (v₂ ∷ vs))
      ≡⟨ sym (printTokenList-++ (printTokens v) (commaT ∷ printArrayTokens (v₂ ∷ vs))) ⟩
    printTokenList (printTokens v ++ (commaT ∷ printArrayTokens (v₂ ∷ vs)))
    ∎
    where open ≡-Reasoning

  printObjectBody-tokens : ∀ (kvs : List (String × JSON)) → printObjectBody kvs ≡ printTokenList (printObjectTokens kvs)
  printObjectBody-tokens [] = refl
  printObjectBody-tokens ((k , v) ∷ []) = cong (λ r → printStringLiteral k ++ (':' ∷ r)) (begin
    printJSON v ++ ('}' ∷ [])
      ≡⟨ cong (_++ ('}' ∷ [])) (printJSON-tokens v) ⟩
    printTokenList (printTokens v) ++ printTokenList (rbraceT ∷ [])
      ≡⟨ sym (printTokenList-++ (printTokens v) (rbraceT ∷ [])) ⟩
    printTokenList (printTokens v ++ (rbraceT ∷ []))
    ∎)
    where open ≡-Reasoning
  printObjectBody-tokens ((k , v) ∷ kv₂ ∷ kvs) = cong (λ r → printStringLiteral k ++ (':' ∷ r)) (begin
    printJSON v ++ (',' ∷ printObjectBody (kv₂ ∷ kvs))
      ≡⟨ cong (_++ (',' ∷ printObjectBody (kv₂ ∷ kvs))) (printJSON-tokens v) ⟩
    printTokenList (printTokens v) ++ (',' ∷ printObjectBody (kv₂ ∷ kvs))
      ≡⟨ cong (λ r → printTokenList (printTokens v) ++ (',' ∷ r)) (printObjectBody-tokens (kv₂ ∷ kvs)) ⟩
    printTokenList (printTokens v) ++ printTokenList (commaT ∷ printObjectTokens (kv₂ ∷ kvs))
      ≡⟨ sym (printTokenList-++ (printTokens v) (commaT ∷ printObjectTokens (kv₂ ∷ kvs))) ⟩
    printTokenList (printTokens v ++ (commaT ∷ printObjectTokens (kv₂ ∷ kvs)))
    ∎)
    where open ≡-Reasoning

------------------------------------------------------------------------
-- 2. String Escaping & Tokenizer Soundness
------------------------------------------------------------------------

correctLexStringChars : ∀ (cs rest : List Char) →
  lexStringChars (escapeString cs ++ ('"' ∷ rest)) ≡ just (cs , rest)
correctLexStringChars [] rest = refl
correctLexStringChars (c ∷ cs) rest with c ≟ '"' | c ≟ '\\' | c ≟ '\n' | c ≟ '\r' | c ≟ '\t'
... | yes refl | _        | _        | _        | _        rewrite correctLexStringChars cs rest = refl
... | no  _    | yes refl | _        | _        | _        rewrite correctLexStringChars cs rest = refl
... | no  _    | no  _    | yes refl | _        | _        rewrite correctLexStringChars cs rest = refl
... | no  _    | no  _    | no  _    | yes refl | _        rewrite correctLexStringChars cs rest = refl
... | no  _    | no  _    | no  _    | no  _    | yes refl rewrite correctLexStringChars cs rest = refl
... | no  ¬q   | no  ¬b   | no  _    | no  _    | no  _    with c ≟ '"'
...   | yes eq = contradiction eq ¬q
...   | no  _  with c ≟ '\\'
...     | yes eq = contradiction eq ¬b
...     | no  _  rewrite correctLexStringChars cs rest = refl

NoLeadingNumberToken : List JSONToken → Set
NoLeadingNumberToken []              = ⊤
NoLeadingNumberToken (numberT _ ∷ _) = ⊥
NoLeadingNumberToken (_ ∷ _)         = ⊤

mutual
  ValidTokenSeq : List JSONToken → Set
  ValidTokenSeq []                 = ⊤
  ValidTokenSeq (numberT _ ∷ ts)   = NoLeadingNumberToken ts × ValidTokenSeq ts
  ValidTokenSeq (_ ∷ ts)           = ValidTokenSeq ts

validTokenSeq-++ : ∀ (xs ys : List JSONToken) →
  ValidTokenSeq xs → NoLeadingNumberToken ys → ValidTokenSeq ys →
  ValidTokenSeq (xs ++ ys)
validTokenSeq-++ [] ys _ _ vys = vys
validTokenSeq-++ (lbraceT ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (rbraceT ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (lbracketT ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (rbracketT ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (colonT ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (commaT ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (nullT ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (boolT _ ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (stringT _ ∷ xs) ys vxs nlys vys = validTokenSeq-++ xs ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ []) ys (_ , _) nlys vys = nlys , vys
validTokenSeq-++ (numberT n ∷ lbraceT ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (lbraceT ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ rbraceT ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (rbraceT ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ lbracketT ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (lbracketT ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ rbracketT ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (rbracketT ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ colonT ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (colonT ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ commaT ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (commaT ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ nullT ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (nullT ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ boolT b ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (boolT b ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ stringT s ∷ xs) ys (_ , vxs) nlys vys = tt , validTokenSeq-++ (stringT s ∷ xs) ys vxs nlys vys
validTokenSeq-++ (numberT n ∷ numberT m ∷ xs) ys (() , _) _ _

mutual
  validPrintTokens : ∀ (v : JSON) → ValidTokenSeq (printTokens v)
  validPrintTokens (pure tt)           = tt
  validPrintTokens (bool _)            = tt
  validPrintTokens (number _)          = tt , tt
  validPrintTokens (string _)          = tt
  validPrintTokens (arrayFromList xs)  = validPrintArrayTokens xs
  validPrintTokens (objectFromlist kvs) = validPrintObjectTokens kvs

  validPrintArrayTokens : ∀ (xs : List JSON) → ValidTokenSeq (printArrayTokens xs)
  validPrintArrayTokens []             = tt
  validPrintArrayTokens (v ∷ [])       = validTokenSeq-++ (printTokens v) (rbracketT ∷ []) (validPrintTokens v) tt tt
  validPrintArrayTokens (v ∷ v₂ ∷ vs)  = validTokenSeq-++ (printTokens v) (commaT ∷ printArrayTokens (v₂ ∷ vs)) (validPrintTokens v) tt (validPrintArrayTokens (v₂ ∷ vs))

  validPrintObjectTokens : ∀ (kvs : List (String × JSON)) → ValidTokenSeq (printObjectTokens kvs)
  validPrintObjectTokens []                    = tt
  validPrintObjectTokens ((k , v) ∷ [])        = validTokenSeq-++ (printTokens v) (rbraceT ∷ []) (validPrintTokens v) tt tt
  validPrintObjectTokens ((k , v) ∷ kv₂ ∷ kvs) = validTokenSeq-++ (printTokens v) (commaT ∷ printObjectTokens (kv₂ ∷ kvs)) (validPrintTokens v) tt (validPrintObjectTokens (kv₂ ∷ kvs))

noLeadingNumCont-TokenList : ∀ (ts : List JSONToken) → NoLeadingNumberToken ts → NoLeadingNumCont (printTokenList ts)
noLeadingNumCont-TokenList []               _  = refl , tt , tt
noLeadingNumCont-TokenList (lbraceT ∷ _)    _  = refl , tt , tt
noLeadingNumCont-TokenList (rbraceT ∷ _)    _  = refl , tt , tt
noLeadingNumCont-TokenList (lbracketT ∷ _)  _  = refl , tt , tt
noLeadingNumCont-TokenList (rbracketT ∷ _)  _  = refl , tt , tt
noLeadingNumCont-TokenList (colonT ∷ _)     _  = refl , tt , tt
noLeadingNumCont-TokenList (commaT ∷ _)     _  = refl , tt , tt
noLeadingNumCont-TokenList (nullT ∷ _)      _  = refl , tt , tt
noLeadingNumCont-TokenList (boolT true ∷ _) _  = refl , tt , tt
noLeadingNumCont-TokenList (boolT false ∷ _) _ = refl , tt , tt
noLeadingNumCont-TokenList (stringT _ ∷ _)  _  = refl , tt , tt
noLeadingNumCont-TokenList (numberT _ ∷ _)  ()

tokenizeDigitStep : ∀ (fuel : ℕ) (d : Fin 10) (tail : List Char) {num rem} →
  lexNumber + (printDigit d ∷ tail) ≡ just (num , rem) →
  tokenizeLoop (suc fuel) (printDigit d ∷ tail) ≡ Maybe.map (numberT num ∷_) (tokenizeLoop fuel rem)
tokenizeDigitStep fuel Data.Fin.Base.zero tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc Data.Fin.Base.zero) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero)) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero))) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero)))) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero))))) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero)))))) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero))))))) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero)))))))) tail eq rewrite eq = refl
tokenizeDigitStep fuel (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc (Data.Fin.Base.suc Data.Fin.Base.zero))))))))) tail eq rewrite eq = refl

tokenizeNumberStep : ∀ (fuel : ℕ) (n : JSONNumber) (ts : List JSONToken) →
  NoLeadingNumberToken ts →
  tokenizeLoop (suc fuel) (printNumber n ++ printTokenList ts) ≡
    Maybe.map (numberT n ∷_) (tokenizeLoop fuel (printTokenList ts))
tokenizeNumberStep fuel (jsonNumber - int frac exp) ts nl
  rewrite correctLexNumberSign - int frac exp (printTokenList ts) (noLeadingNumCont-TokenList ts nl) = refl
tokenizeNumberStep fuel (jsonNumber + int frac exp) ts nl =
  let eqLex = correctLexNumberSign + int frac exp (printTokenList ts) (noLeadingNumCont-TokenList ts nl)
  in helper (natToDigits int) (natToDigits-nonEmpty int) eqLex
  where
    helper : ∀ (ds : List (Fin 10)) → NonEmptyList ds →
      lexNumber + ((printDigits ds ++ printFraction frac ++ printExponent exp) ++ printTokenList ts) ≡
        just (jsonNumber + int frac exp , printTokenList ts) →
      tokenizeLoop (suc fuel) ((printDigits ds ++ printFraction frac ++ printExponent exp) ++ printTokenList ts) ≡
        Maybe.map (numberT (jsonNumber + int frac exp) ∷_) (tokenizeLoop fuel (printTokenList ts))
    helper [] () _
    helper (d ∷ ds) _ eq = tokenizeDigitStep fuel d ((printDigits ds ++ printFraction frac ++ printExponent exp) ++ printTokenList ts) eq

correctTokenizeLoop : ∀ (ts : List JSONToken) (extra : ℕ) →
  ValidTokenSeq ts →
  tokenizeLoop (suc (length ts + extra)) (printTokenList ts) ≡ just ts
correctTokenizeLoop [] extra _ = refl
correctTokenizeLoop (lbraceT ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (rbraceT ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (lbracketT ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (rbracketT ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (colonT ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (commaT ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (nullT ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (boolT true ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (boolT false ∷ ts) extra vts rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (stringT s ∷ ts) extra vts
  rewrite ++-assoc (escapeString (toList s)) ('"' ∷ []) (printTokenList ts)
  rewrite correctLexStringChars (toList s) (printTokenList ts)
  rewrite primStringToListInv s
  rewrite correctTokenizeLoop ts extra vts = refl
correctTokenizeLoop (numberT n ∷ ts) extra (nl , vts)
  rewrite tokenizeNumberStep (length ts + extra) n ts nl
  rewrite correctTokenizeLoop ts extra vts = refl

tokenExtra : JSONToken → ℕ
tokenExtra lbraceT       = 0
tokenExtra rbraceT       = 0
tokenExtra lbracketT     = 0
tokenExtra rbracketT     = 0
tokenExtra colonT        = 0
tokenExtra commaT        = 0
tokenExtra nullT         = 3
tokenExtra (boolT true)  = 3
tokenExtra (boolT false) = 4
tokenExtra (stringT s)   = suc (length (escapeString (toList s) ++ ('"' ∷ [])))
tokenExtra (numberT (jsonNumber - int frac exp)) = length (printNat int ++ printFraction frac ++ printExponent exp)
tokenExtra (numberT (jsonNumber + int frac exp)) with natToDigits int | natToDigits-nonEmpty int
... | []     | ()
... | d ∷ ds | _ = length (printDigits ds ++ printFraction frac ++ printExponent exp)

length-printToken : ∀ (t : JSONToken) → length (printToken t) ≡ suc (tokenExtra t)
length-printToken lbraceT       = refl
length-printToken rbraceT       = refl
length-printToken lbracketT     = refl
length-printToken rbracketT     = refl
length-printToken colonT        = refl
length-printToken commaT        = refl
length-printToken nullT         = refl
length-printToken (boolT true)  = refl
length-printToken (boolT false) = refl
length-printToken (stringT s)   = refl
length-printToken (numberT (jsonNumber - int frac exp)) = refl
length-printToken (numberT (jsonNumber + int frac exp)) with natToDigits int | natToDigits-nonEmpty int
... | []     | ()
... | d ∷ ds | _ = refl

tokenListExtra : List JSONToken → ℕ
tokenListExtra []       = 0
tokenListExtra (t ∷ ts) = tokenExtra t + tokenListExtra ts

length-printTokenList : ∀ (ts : List JSONToken) →
  length (printTokenList ts) ≡ length ts + tokenListExtra ts
length-printTokenList [] = refl
length-printTokenList (t ∷ ts)
  rewrite length-++ (printToken t) {printTokenList ts}
  rewrite length-printToken t
  rewrite length-printTokenList ts
  rewrite +-assoc (tokenExtra t) (length ts) (tokenListExtra ts)
  rewrite +-comm (tokenExtra t) (length ts)
  rewrite sym (+-assoc (length ts) (tokenExtra t) (tokenListExtra ts))
  = refl

correctTokenize : ∀ (v : JSON) → tokenize (printJSON v) ≡ just (printTokens v)
correctTokenize v
  rewrite printJSON-tokens v
  rewrite length-printTokenList (printTokens v)
  = correctTokenizeLoop (printTokens v) (tokenListExtra (printTokens v)) (validPrintTokens v)

------------------------------------------------------------------------
-- 3. Recursive-Descent Token Parser Soundness
------------------------------------------------------------------------

parseElemAndContinue : ∀ (fuel : ℕ) (v : JSON) (tailToks : List JSONToken) →
  (parseValue fuel (printTokens v ++ tailToks) ≡ just (v , tailToks)) →
  parseArrayElements (suc fuel) (printTokens v ++ tailToks) ≡ continueArray fuel v tailToks
parseElemAndContinue fuel (pure tt)           tailToks eq rewrite eq = refl
parseElemAndContinue fuel (bool _)            tailToks eq rewrite eq = refl
parseElemAndContinue fuel (number _)          tailToks eq rewrite eq = refl
parseElemAndContinue fuel (string _)          tailToks eq rewrite eq = refl
parseElemAndContinue fuel (arrayFromList _)   tailToks eq rewrite eq = refl
parseElemAndContinue fuel (objectFromlist _)   tailToks eq rewrite eq = refl

continueArrayCons : ∀ (fuel : ℕ) (v : JSON) (tailToks : List JSONToken) {vs rem'} →
  parseArrayElements fuel tailToks ≡ just (vs , rem') →
  continueArray fuel v (commaT ∷ tailToks) ≡ just (v ∷ vs , rem')
continueArrayCons fuel v tailToks eq rewrite eq = refl

continueObjectCons : ∀ (fuel : ℕ) (k : String) (v : JSON) (tailToks : List JSONToken) {kvs rem''} →
  parseObjectEntries fuel tailToks ≡ just (kvs , rem'') →
  continueObject fuel k v (commaT ∷ tailToks) ≡ just ((k , v) ∷ kvs , rem'')
continueObjectCons fuel k v tailToks eq rewrite eq = refl

mutual
  correctParseValue : ∀ (v : JSON) (extra : ℕ) (rest : List JSONToken) →
    parseValue (length (printTokens v) + extra) (printTokens v ++ rest) ≡ just (v , rest)
  correctParseValue (pure tt) extra rest = refl
  correctParseValue (bool b)  extra rest = refl
  correctParseValue (number n) extra rest = refl
  correctParseValue (string s) extra rest = refl
  correctParseValue (arrayFromList xs) extra rest
    rewrite correctParseArray xs extra rest = refl
  correctParseValue (objectFromlist kvs) extra rest
    rewrite correctParseObject kvs extra rest = refl

  correctParseArray : ∀ (xs : List JSON) (extra : ℕ) (rest : List JSONToken) →
    parseArrayElements (length (printArrayTokens xs) + extra) (printArrayTokens xs ++ rest) ≡ just (xs , rest)
  correctParseArray [] extra rest = refl
  correctParseArray (v ∷ []) extra rest
    rewrite ++-assoc (printTokens v) (rbracketT ∷ []) rest
    rewrite length-++ (printTokens v) {rbracketT ∷ []}
    rewrite +-assoc (length (printTokens v)) 1 extra
    rewrite +-comm (length (printTokens v)) (1 + extra)
    = parseElemAndContinue (length (printTokens v) + extra) v (rbracketT ∷ rest)
        (correctParseValue v extra (rbracketT ∷ rest))
  correctParseArray (v ∷ v₂ ∷ vs) extra rest
    rewrite ++-assoc (printTokens v) (commaT ∷ printArrayTokens (v₂ ∷ vs)) rest
    rewrite length-++ (printTokens v) {commaT ∷ printArrayTokens (v₂ ∷ vs)}
    rewrite +-assoc (length (printTokens v)) (suc (length (printArrayTokens (v₂ ∷ vs)))) extra
    rewrite +-comm (length (printTokens v)) (suc (length (printArrayTokens (v₂ ∷ vs)) + extra))
    = let L₁ = length (printTokens v)
          L₂ = length (printArrayTokens (v₂ ∷ vs))
          fuel = L₂ + extra + L₁
          eqV : parseValue fuel (printTokens v ++ (commaT ∷ printArrayTokens (v₂ ∷ vs) ++ rest)) ≡
                  just (v , commaT ∷ printArrayTokens (v₂ ∷ vs) ++ rest)
          eqV rewrite +-comm (L₂ + extra) L₁
                    | +-assoc L₁ L₂ extra
                    = correctParseValue v (L₂ + extra) (commaT ∷ printArrayTokens (v₂ ∷ vs) ++ rest)
          eqRec : parseArrayElements fuel (printArrayTokens (v₂ ∷ vs) ++ rest) ≡ just (v₂ ∷ vs , rest)
          eqRec rewrite +-assoc L₂ extra L₁
                = correctParseArray (v₂ ∷ vs) (extra + L₁) rest
          step = parseElemAndContinue fuel v (commaT ∷ printArrayTokens (v₂ ∷ vs) ++ rest) eqV
      in trans step (continueArrayCons fuel v (printArrayTokens (v₂ ∷ vs) ++ rest) eqRec)

  correctParseObject : ∀ (kvs : List (String × JSON)) (extra : ℕ) (rest : List JSONToken) →
    parseObjectEntries (length (printObjectTokens kvs) + extra) (printObjectTokens kvs ++ rest) ≡ just (kvs , rest)
  correctParseObject [] extra rest = refl
  correctParseObject ((k , v) ∷ []) extra rest
    rewrite ++-assoc (printTokens v) (rbraceT ∷ []) rest
    rewrite length-++ (printTokens v) {rbraceT ∷ []}
    rewrite +-assoc (length (printTokens v)) 1 extra
    rewrite +-comm (length (printTokens v)) (1 + extra)
    rewrite correctParseValue v (1 + extra) (rbraceT ∷ rest) = refl
  correctParseObject ((k , v) ∷ kv₂ ∷ kvs) extra rest
    rewrite ++-assoc (printTokens v) (commaT ∷ printObjectTokens (kv₂ ∷ kvs)) rest
    rewrite length-++ (printTokens v) {commaT ∷ printObjectTokens (kv₂ ∷ kvs)}
    rewrite +-assoc (length (printTokens v)) (suc (length (printObjectTokens (kv₂ ∷ kvs)))) extra
    rewrite +-comm (length (printTokens v)) (suc (length (printObjectTokens (kv₂ ∷ kvs)) + extra))
    = let L₁ = length (printTokens v)
          L₂ = length (printObjectTokens (kv₂ ∷ kvs))
          fuel = suc (L₂ + extra + L₁)
          eqV : parseValue fuel (printTokens v ++ (commaT ∷ printObjectTokens (kv₂ ∷ kvs) ++ rest)) ≡
                  just (v , commaT ∷ printObjectTokens (kv₂ ∷ kvs) ++ rest)
          eqV rewrite +-comm (L₂ + extra) L₁
                    | +-assoc L₁ L₂ extra
                    | sym (+-comm (L₁ + (L₂ + extra)) 1)
                    | +-assoc L₁ (L₂ + extra) 1
                    = correctParseValue v (L₂ + extra + 1) (commaT ∷ printObjectTokens (kv₂ ∷ kvs) ++ rest)
          eqRec : parseObjectEntries fuel (printObjectTokens (kv₂ ∷ kvs) ++ rest) ≡ just (kv₂ ∷ kvs , rest)
          eqRec rewrite sym (+-comm (L₂ + extra + L₁) 1)
                      | +-assoc L₂ (extra + L₁) 1
                      | +-assoc L₂ extra L₁
                      = correctParseObject (kv₂ ∷ kvs) (extra + L₁ + 1) rest
      in helper eqV eqRec
    where
      helper : ∀ {fuel tailToks} →
        parseValue fuel (printTokens v ++ (commaT ∷ tailToks)) ≡ just (v , commaT ∷ tailToks) →
        parseObjectEntries fuel tailToks ≡ just (kv₂ ∷ kvs , rest) →
        parseObjectEntries (suc fuel) (stringT k ∷ colonT ∷ printTokens v ++ (commaT ∷ tailToks)) ≡ just ((k , v) ∷ kv₂ ∷ kvs , rest)
      helper {fuel} {tailToks} eqV eqRec rewrite eqV = continueObjectCons fuel k v tailToks eqRec

------------------------------------------------------------------------
-- 4. Universal JSON Round-Trip Theorem & LeftInverse Bundle
------------------------------------------------------------------------

-- Universal round-trip theorem: parsing the printed characters of ANY JSON recovers it
roundTripJSON : ∀ (v : JSON) → parseJSON (printJSON v) ≡ just v
roundTripJSON v
  rewrite correctTokenize v
  rewrite sym (+-comm (length (printTokens v)) 1)
  rewrite sym (++-identityʳ (printTokens v))
  rewrite correctParseValue v 1 []
  = refl

-- Total JSON parser with null fallback
parseJSONTotal : List Char → JSON
parseJSONTotal cs with parseJSON cs
... | just v  = v
... | nothing = null

-- Universal retraction theorem: parseJSONTotal is a left inverse to printJSON for ALL JSON
jsonRetraction : ∀ (v : JSON) → parseJSONTotal (printJSON v) ≡ v
jsonRetraction v rewrite roundTripJSON v = refl

-- Inverseˡ property required by Data.Function.Bundles.LeftInverse
jsonLeftInverseˡ : ∀ {v : JSON} {cs : List Char} → cs ≡ printJSON v → parseJSONTotal cs ≡ v
jsonLeftInverseˡ {v} refl = jsonRetraction v

-- Unconditional stdlib LeftInverse bundle: List Char ↩ JSON
-- with to = parseJSONTotal (pseudo-inverse) and from = printJSON (injection)
jsonLeftInverse : List Char ↩ JSON
jsonLeftInverse = mk↩ {to = parseJSONTotal} {from = printJSON} jsonLeftInverseˡ
