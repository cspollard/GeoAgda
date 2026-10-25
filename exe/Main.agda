{-# OPTIONS --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module Main where

open import Agda.Builtin.IO using (IO)
open import Agda.Builtin.Unit using () renaming (⊤ to Unit; tt to unit)
open import Data.String as String using (String; _++_)
open import Data.List using ([]; _∷_)
open import Data.Maybe using (just; nothing)
open import Function using (case_of_)

open import IO.Primitive.Core using (_>>=_; _>>_)
open import IO.Primitive.Finite using (readFile; writeFile; putStrLn)
open import System.Environment.Primitive using (getArgs)

open import GeoAgda.Pipeline using (geojsonStringToSVG)

------------------------------------------------------------------------
-- Core Processing Routine
------------------------------------------------------------------------

say : String → IO Unit
say msg = putStrLn ("[GeoAgda] " ++ msg)

processGeoJSON : String → String → IO Unit
processGeoJSON inFile outFile =
  say ("Reading GeoJSON input from: " ++ inFile) >>
  (readFile inFile >>= λ geojson →
   case geojsonStringToSVG geojson of λ where
     (just svg) →
       say "Parsed GeoJSON and rendered SVG" >>
       (say ("Writing SVG output to: " ++ outFile) >>
        (writeFile outFile svg >>
         say "Done!"))
     nothing →
       say ("Error: Failed to parse or extract GeoJSON from " ++ inFile))

------------------------------------------------------------------------
-- Executable Main Entry Point
------------------------------------------------------------------------

main : IO Unit
main =
  getArgs >>= λ where
    []                      → processGeoJSON "data/fixtures/natural_earth_sample.geojson" "example.svg"
    (inFile ∷ [])           → processGeoJSON inFile "example.svg"
    (inFile ∷ outFile ∷ _)  → processGeoJSON inFile outFile
