{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda where

-- JSON AST, Container signature, Free Monad, and Serialization
open import GeoAgda.Data.JSON.AST public
open import GeoAgda.Data.JSON.Print public

-- XML / SVG AST, Container signature, Free Monad, and Serialization
open import GeoAgda.Data.XML.AST public
open import GeoAgda.Data.XML.Print public

-- Invertible Parsing Primitives & Combinators
open import GeoAgda.Parsing.Invertible.Core public
open import GeoAgda.Parsing.Invertible.Char public
open import GeoAgda.Parsing.Invertible.Number public
open import GeoAgda.Parsing.Invertible.Combinators public

-- JSON Lexer and Parser
open import GeoAgda.Parsing.JSON.Lexer public
open import GeoAgda.Parsing.JSON.Parser public
open import GeoAgda.Parsing.JSON.Soundness public

-- Schema Validation & GeoJSON Models
open import GeoAgda.Data.JSON.Schema public
open import GeoAgda.Model.GeoJSON.Types public
open import GeoAgda.Model.GeoJSON.Extraction public

-- SVG Map Rendering Pipeline
open import GeoAgda.Rendering.SVG.Coordinates public
open import GeoAgda.Rendering.SVG.Render public
