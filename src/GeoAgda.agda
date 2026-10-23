{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda where

-- JSON AST, Container signature, Free Monad, and Serialization
open import Data.JSON.AST public
open import Data.JSON.Print public

-- XML / SVG AST, Container signature, Free Monad, and Serialization
open import Data.XML.AST public
open import Data.XML.Print public

-- Invertible Parsing Primitives & Combinators
open import GeoAgda.Parsing.Invertible.Core public
open import GeoAgda.Parsing.Invertible.Char public
open import GeoAgda.Parsing.Invertible.Number public
open import GeoAgda.Parsing.Invertible.Combinators public

-- JSON Lexer, Parser, and the round-trip theorem
open import GeoAgda.Parsing.JSON.Lexer public
open import GeoAgda.Parsing.JSON.Parser public
open import Data.JSON.RoundTrip public

-- XML & SVG Lexer, Parser, and Invertible Soundness
open import GeoAgda.Parsing.XML.Parser public
open import GeoAgda.Parsing.XML.Soundness public

-- Schema Validation, Conformance & Typed GeoJSON Models
open import Data.JSON.Schema public
open import Data.JSON.Conformance public
open import GeoAgda.Model.GeoJSON.Types public
open import GeoAgda.Model.GeoJSON.Extraction public
open import GeoAgda.Model.GeoJSON.Conformance public

-- SVG Map Rendering Pipeline
open import GeoAgda.Rendering.SVG.Coordinates public
open import GeoAgda.Rendering.SVG.Render public

-- End-to-End Ingestion & Rendering Pipeline
open import GeoAgda.Pipeline public
