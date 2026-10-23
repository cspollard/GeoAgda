{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Compatibility shim: the JSON tokens and tokenizer now live in
-- `Data.JSON.Token` and `Data.JSON.Lexer`.
module GeoAgda.Parsing.JSON.Lexer where

open import Data.JSON.Token using (JSONToken) public
open import Data.JSON.Lexer using (tokenize) public
