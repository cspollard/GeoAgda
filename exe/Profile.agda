{-# OPTIONS --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Stage-by-stage profiling driver: `Profile <stage> <file>` runs the
-- pipeline up to `<stage>` and prints a number that forces the work.
-- Stages: read, tokenize, parse, json (parse + print), extract, svg, and
-- the micro-benchmarks below (xmlbig, numbers, path, centroid, style, …).
module Profile where

open import Agda.Builtin.IO using (IO)
open import Data.Integer using (+_)
open import Data.List using (List; []; _∷_; length; map; foldr; concat; replicate; iterate)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Nat using (ℕ; suc; _+_)
import Data.Nat.Show as NatShow
open import Data.Product using (_,_)
import Data.Sign as Sign
open import Data.String using (String; fromList; toList)
open import Function using (_∘_)
import IO.Primitive.Core as IO
open import IO.Primitive.Finite using (readFile; putStrLn)
open import System.Environment.Primitive using (getArgs)

open import Data.JSON.AST using (jsonNumber)
open import Data.JSON.Lexer using (tokenize; tokenizeLoop)
open import Data.JSON.Parser using (parseTokens)
open import Data.JSON.Print using (printJSON)
open import Data.JSON.RoundTrip using (parseJSON)
open import Data.SVG using (svg; g; path)
open import Data.XML.Print using (printXML)
open import Data.XML.Sanitize using (element)
open import GeoAgda.Model.GeoJSON.Extraction using (extractFeatureCollection)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Rendering.SVG.Coordinates
  using (renderJSONNumber; equirectangular; featureCentroid; formatPolygonD; formatMultiPolygonD)
open import GeoAgda.Rendering.SVG.NaturalEarth using (featureTerrainStyle)
open import GeoAgda.Rendering.SVG.Render using (renderMapSVG; renderFeature)
open import GeoAgda.Rendering.SVG.Style using (SVGStyle; defaultTerrainStyle; defaultPolygonStyle)

orZero : Maybe ℕ → ℕ
orZero = Maybe.fromMaybe 0

lengthOf : ∀ {A : Set} → Maybe (List A) → ℕ
lengthOf = orZero ∘ Maybe.map length

sumOver : ∀ {A : Set} → (A → ℕ) → List A → ℕ
sumOver f = foldr _+_ 0 ∘ map f

-- The feature collection of a GeoJSON document (0 when it does not parse).
withFeatures : String → (List Feature → ℕ) → ℕ
withFeatures s k with parseJSON (toList s) >>= extractFeatureCollection
... | nothing                       = 0
... | just (featureCollection fs _) = k fs

withCollection : String → (FeatureCollection → ℕ) → ℕ
withCollection s k = orZero (Maybe.map k (parseJSON (toList s) >>= extractFeatureCollection))

-- 100 000 generated coordinates, rendered.
renderNumbers : (ℕ → ℕ) → ℕ
renderNumbers f =
  length (concat (map (λ n → toList (renderJSONNumber (jsonNumber Sign.+ (f n) [] (+ 0))))
                      (iterate suc 0 100000)))

pathLength : Feature → ℕ
pathLength (feature _ (polygonG rs) _)       = length (toList (formatPolygonD equirectangular rs))
pathLength (feature _ (multiPolygonG ps) _)  = length (toList (formatMultiPolygonD equirectangular ps))
pathLength _                                 = 0

fillLength : Feature → ℕ
fillLength (feature _ _ ps) =
  length (toList (Maybe.fromMaybe "" (SVGStyle.fill (featureTerrainStyle defaultTerrainStyle ps))))

aLong : ℕ → String
aLong n = fromList (replicate n 'a')

run : String → String → ℕ
run "read"       s = length (toList s)
run "tokenize"   s = lengthOf (tokenize (toList s))
run "parse"      s = orZero (tokenize (toList s) >>= λ ts → Maybe.map (λ _ → 1) (parseTokens ts))
run "json"       s = lengthOf (Maybe.map printJSON (parseJSON (toList s)))
run "extract"    s = withFeatures s length
run "svg"        s = withCollection s (length ∘ printXML ∘ renderMapSVG defaultTerrainStyle)
run "svgplain"   s = withCollection s (length ∘ printXML ∘ renderMapSVG defaultPolygonStyle)
run "svgfeat"    s = withFeatures s (sumOver (length ∘ printXML ∘ renderFeature equirectangular defaultPolygonStyle))
run "path"       s = withFeatures s (sumOver pathLength)
run "centroid"   s = withFeatures s (sumOver (orZero ∘ Maybe.map (λ _ → 1) ∘ featureCentroid))
run "style"      s = withFeatures s (sumOver fillLength)
run "xmlbig"     s = length (printXML (element "p" (("d" , aLong 100000) ∷ []) []))
run "numbers"    s = renderNumbers (_% 180)
run "numbersbig" s = renderNumbers (λ n → n)
run "svgsimple"  s = length (printXML (svg [] (g [] (path (aLong 20000) [] ∷ []) ∷ [])))
run "svgflat"    s = length (printXML (svg [] (path (aLong 20000) [] ∷ [])))
run "pathonly"   s = length (printXML (path (aLong 20000) []))
run "tokbig"     s = lengthOf (tokenizeLoop 1000000000 (toList s))
run _            s = 0

main : IO _
main = getArgs IO.>>= λ where
  (stage ∷ file ∷ _) → readFile file IO.>>= λ s → putStrLn (NatShow.show (run stage s))
  _ → putStrLn "usage: Profile <stage> <file>"
