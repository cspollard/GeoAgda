{-# OPTIONS --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module Main where

open import Agda.Builtin.IO using (IO)
open import Agda.Builtin.Unit using () renaming (⊤ to Unit; tt to unit)
open import Data.String as String using (String; _++_)
open import Data.List using (List; []; _∷_)
open import Data.Maybe using (Maybe; just; nothing)

open import IO.Primitive.Core using (pure; _>>=_; _>>_)
open import IO.Primitive.Finite using (readFile; writeFile; putStrLn)
open import System.Environment.Primitive using (getArgs)

open import GeoAgda.Pipeline using (geojsonStringToSVG)

------------------------------------------------------------------------
-- Core Processing Routine
------------------------------------------------------------------------

processGeoJSON : String → String → IO Unit
processGeoJSON inFile outFile =
  putStrLn ("[GeoAgda] Reading GeoJSON input from: " ++ inFile) >>
  (readFile inFile >>= λ jsonContent →
   case (geojsonStringToSVG jsonContent) of λ where
     (just svgContent) →
       putStrLn ("[GeoAgda] Successfully parsed GeoJSON and rendered SVG (" ++ inFile ++ ")") >>
       (putStrLn ("[GeoAgda] Writing SVG output to: " ++ outFile) >>
        (writeFile outFile svgContent >>
         putStrLn "[GeoAgda] Done!"))
     nothing →
       putStrLn ("[GeoAgda] Error: Failed to parse or extract GeoJSON from " ++ inFile))
  where
    case_of_ : ∀ {A B : Set} → A → (A → B) → B
    case x of f = f x

------------------------------------------------------------------------
-- Executable Main Entry Point
------------------------------------------------------------------------

main : IO Unit
main =
  getArgs >>= λ where
    []                      → processGeoJSON "data/fixtures/natural_earth_sample.geojson" "example.svg"
    (inFile ∷ [])           → processGeoJSON inFile "example.svg"
    (inFile ∷ outFile ∷ _)  → processGeoJSON inFile outFile
