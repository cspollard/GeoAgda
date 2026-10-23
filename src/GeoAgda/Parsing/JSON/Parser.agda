{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Compatibility shim: the JSON parser now lives in `Data.JSON.Parser`
-- and `Data.JSON.RoundTrip` (where its round-trip proof is, too).
module GeoAgda.Parsing.JSON.Parser where

open import Data.JSON.RoundTrip using (parseJSON) public
