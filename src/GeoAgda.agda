{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda where

-- JSON AST, Container signature, Free Monad, and Serialization
open import Data.JSON.AST public
open import Data.JSON.Print public

-- XML / SVG AST, Container signature, Free Monad, and Serialization
open import Data.XML.AST public
open import Data.XML.Sanitize public
open import Data.XML.Print public
open import Data.XML.RoundTrip public
open import Data.SVG public

-- Invertible parsing, the JSON lexer/parser and its round-trip theorem
open import Data.Invertible.Core public
open import Data.Invertible.Char public
open import Data.Invertible.Combinators public
open import Data.JSON.Number public
open import Data.JSON.Lexer public
open import Data.JSON.Parser public
open import Data.JSON.RoundTrip public

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
