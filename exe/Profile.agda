{-# OPTIONS --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Stage-by-stage profiling driver: `Profile <stage> <file>` runs the
-- pipeline up to `<stage>` and prints a number that forces the work.
-- Stages: read, tokenize, parse, json (parse + print), extract, svg.
module Profile where

open import Agda.Builtin.IO using (IO)
open import Agda.Builtin.Unit using () renaming (⊤ to Unit)
open import Data.String as String using (String; _++_; toList)
open import Data.List using (List; []; _∷_; length)
open import Data.Maybe using (Maybe; just; nothing)
open import Data.Nat using (ℕ; _%_)
import Data.Nat
import Data.Nat.Show as NatShow
open import IO.Primitive.Core using (pure; _>>=_; _>>_)
open import IO.Primitive.Finite using (readFile; putStrLn)
open import System.Environment.Primitive using (getArgs)

open import Data.List using (replicate)
open import Data.Char using (Char)
open import Data.String using (fromList)
open import Data.Product using (_,_)
open import Data.Fin using (Fin)
open import Data.JSON.AST using (jsonNumber)
open import Data.JSON.Print using (printNumber)
open import Data.Sign using (Sign)
open import Data.Integer using (+_)
open import Data.XML.Sanitize using (element)
open import Data.SVG using (svg; g; path)
open import GeoAgda.Rendering.SVG.Coordinates using (renderJSONNumber)
open import Data.JSON.Lexer using (tokenize)
open import Data.JSON.RoundTrip using (parseJSON)
open import Data.JSON.Print using (printJSON)
open import Data.JSON.Parser using (parseTokens)
open import Data.XML.Print using (printXML)
open import GeoAgda.Model.GeoJSON.Types using (FeatureCollection; featureCollection)
open import GeoAgda.Model.GeoJSON.Extraction using (extractFeatureCollection)
open import GeoAgda.Rendering.SVG.Render using (renderMapSVG; defaultTerrainStyle; defaultPolygonStyle; renderFeature; featureTerrainStyle; SVGStyle; featureName)
open import GeoAgda.Rendering.SVG.Coordinates using (equirectangular; featureCentroid; formatPolygonD; formatMultiPolygonD)
open import GeoAgda.Model.GeoJSON.Types using (feature; Feature; polygonG; multiPolygonG; Geometry)
open import Data.List using (map)
open import Data.Nat using (_+_)
open import Data.List using (foldr)

orZero : Maybe ℕ → ℕ
orZero (just n) = n
orZero nothing  = 0

count : Maybe FeatureCollection → ℕ
count (just (featureCollection fs _)) = length fs
count nothing = 0

run : String → String → ℕ
run "read"     s = length (toList s)
run "tokenize" s = orZero (Data.Maybe.map length (tokenize (toList s)))
run "parse"    s with tokenize (toList s)
... | nothing = 0
... | just ts with parseTokens ts
...   | just _  = 1
...   | nothing = 0
run "json"     s = orZero (Data.Maybe.map (λ v → length (printJSON v)) (parseJSON (toList s)))
run "extract"  s with parseJSON (toList s)
... | nothing = 0
... | just v  = count (extractFeatureCollection v)
run "svg"      s with parseJSON (toList s)
... | nothing = 0
... | just v  with extractFeatureCollection v
...   | nothing = 0
...   | just fc = length (printXML (renderMapSVG defaultTerrainStyle fc))
run "xmlbig"   s = length (printXML (element "p" (("d" , fromList (replicate 100000 'a')) ∷ []) []))
run "numbers"  s = length (Data.List.concat (Data.List.map (λ n → toList (renderJSONNumber (jsonNumber Sign.+ (n Data.Nat.% 180) [] (+ 0)))) (Data.List.iterate Data.Nat.suc 0 100000)))
run "numbersbig"  s = length (Data.List.concat (Data.List.map (λ n → toList (renderJSONNumber (jsonNumber Sign.+ n [] (+ 0)))) (Data.List.iterate Data.Nat.suc 0 100000)))
run "path"     s with parseJSON (toList s) Data.Maybe.>>= extractFeatureCollection
... | nothing = 0
... | just (featureCollection fs _) = foldr _+_ 0 (map pathLen fs)
  where
  pathLen : Feature → ℕ
  pathLen (feature _ (polygonG rs) _) = length (toList (formatPolygonD equirectangular rs))
  pathLen (feature _ (multiPolygonG ps) _) = length (toList (formatMultiPolygonD equirectangular ps))
  pathLen _ = 0
run "centroid" s with parseJSON (toList s) Data.Maybe.>>= extractFeatureCollection
... | nothing = 0
... | just (featureCollection fs _) = foldr _+_ 0 (map (λ f → orZero (Data.Maybe.map (λ _ → 1) (featureCentroid f))) fs)
run "style"    s with parseJSON (toList s) Data.Maybe.>>= extractFeatureCollection
... | nothing = 0
... | just (featureCollection fs _) = foldr _+_ 0 (map (λ { (feature _ _ ps) → length (toList (orStr (SVGStyle.fill (featureTerrainStyle defaultTerrainStyle ps)))) }) fs)
  where
  orStr : Maybe String → String
  orStr (just x) = x
  orStr nothing = ""
run "svgsimple" s = length (printXML (svg [] (g [] (path (fromList (replicate 20000 'a')) [] ∷ []) ∷ [])))
run "svgflat"   s = length (printXML (svg [] (path (fromList (replicate 20000 'a')) [] ∷ [])))
run "pathonly"  s = length (printXML (path (fromList (replicate 20000 'a')) []))
run "svgplain" s with parseJSON (toList s) Data.Maybe.>>= extractFeatureCollection
... | nothing = 0
... | just fc = length (printXML (renderMapSVG defaultPolygonStyle fc))
run "svgfeat" s with parseJSON (toList s) Data.Maybe.>>= extractFeatureCollection
... | nothing = 0
... | just (featureCollection fs _) = foldr _+_ 0 (map (λ f → length (printXML (renderFeature equirectangular defaultPolygonStyle f))) fs)
run _          s = 0

main : IO Unit
main = getArgs >>= λ where
  (stage ∷ file ∷ _) → readFile file >>= λ s → putStrLn (NatShow.show (run stage s))
  _ → putStrLn "usage: Profile <stage> <file>"
