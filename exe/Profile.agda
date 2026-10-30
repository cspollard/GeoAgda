{-# OPTIONS --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Stage-by-stage profiling driver: `Profile <stage> <file>` runs the
-- pipeline up to `<stage>` and prints a number that forces the work.
-- Stages: read, tokenize, parse, json (parse + print), extract, svg, and
-- the micro-benchmarks below (xmlbig, numbers, path, centroid, style, …).
module Profile where

open import Agda.Builtin.IO using (IO)
open import Data.Integer using (+_)
open import Data.List using (List; []; _∷_; _++_; length; map; foldr; concat; replicate; iterate)
open import Data.Maybe as Maybe using (Maybe; just; nothing; _>>=_)
open import Data.Nat using (ℕ; zero; suc; _+_; _%_)
import Data.Nat.Show as NatShow
open import Data.Product using (_,_)
import Data.Sign as Sign
open import Data.String using (String; fromList; toList)
open import Function using (_∘_; case_of_)
open import Function.Strict using (_$!′_)
import IO.Primitive.Core as IO
open import IO.Primitive.Finite using (readFile; writeFile; putStrLn)
open import System.Environment.Primitive using (getArgs)

open import Data.JSON.AST using (jsonNumber)
open import Data.JSON.Lexer using (tokenize; tokenizeLoop)
open import Data.JSON.Parser using (parseTokens)
open import Data.JSON.Print using (printJSON)
open import Data.JSON.RoundTrip using (parseJSON)
open import Data.SVG using (svg; g; path)
open import Data.XML.Print using (printXML)
open import Data.XML.Tokens using (printTokens)
open import Data.XML.Escape using (escapeValue)
open import Data.Sanitize using (fixText)
open import Data.XML.Sanitize using (element)
open import GeoAgda.Compose using (applyLayer)
open import GeoAgda.Compose.Earth using (oceanBand)
open import GeoAgda.Compose.Options using (defaultOptions; Options)
open import GeoAgda.Model.GeoJSON.Extraction using (extractFeatureCollection; extractLocatedFeatureCollection)
open import GeoAgda.Model.GeoJSON.Reduce using (exactGeometry)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.Path using (pathWeight; pathRings; polygonP)
open import GeoAgda.Rendering.SVG.Coordinates
  using (renderJSONNumber; equirectangular; featureCentroid; formatPolygonD; formatMultiPolygonD)
open import GeoAgda.Rendering.SVG.NaturalEarth using (featureTerrainStyle)
open import GeoAgda.Rendering.SVG.Path using (renderPath)
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
pathLength (feature _ (pathG p) _)           = length (renderPath equirectangular p)
pathLength _                                 = 0

fillLength : Feature → ℕ
fillLength (feature _ _ ps) =
  length (toList (Maybe.fromMaybe "" (SVGStyle.fill (featureTerrainStyle defaultTerrainStyle ps))))

-- Forces a converted polygon (0 for anything else).
weightOf : Geometry → ℕ
weightOf (pathG p) = pathWeight p
weightOf _         = 0

-- Weight of a plain geometry (digits of every coordinate), forcing it.
geomW : Geometry → ℕ
geomW (polygonG rs)     = ringsW rs
  where
    posW : Position → ℕ
    posW (pos (jsonNumber _ a f _) (jsonNumber _ b f′ _)) = a + b + length f + length f′ + 1
    ringsW : List (List Position) → ℕ
    ringsW = foldr (λ r acc → foldr (λ p a → posW p + a) acc r) 0
geomW (multiPolygonG ps) = foldr (λ rs acc → geomW (polygonG rs) + acc) 0 ps
geomW _                 = 0

-- Force the geometries, then hold them live (and traverse them again) so that a heap profile
-- sees only what is retained.
keepWeight : (Geometry → ℕ) → List Geometry → ℕ
keepWeight w gs = loop 150 0
  where
    loop : ℕ → ℕ → ℕ
    loop zero    acc = acc
    loop (suc n) acc = loop n (acc + sumOver w gs)

-- Features rebuilt as `Compose.Earth.rebuild` does, held live while traversed again.
keepFeatures : List Feature → ℕ
keepFeatures fs = loop 150 0
  where
    loop : ℕ → ℕ → ℕ
    loop zero    acc = acc
    loop (suc n) acc = loop n (acc + sumOver (λ f → weightOf (Feature.geometry f) + length (Feature.properties f)) fs)

-- Like `keepFeatures` but forcing only the geometry, as `exe/Earth`'s `weight` does.
keepGeoms : List Feature → ℕ
keepGeoms fs = loop 150 0
  where
    loop : ℕ → ℕ → ℕ
    loop zero    acc = acc
    loop (suc n) acc = loop n (acc + sumOver (λ f → weightOf (Feature.geometry f)) fs)

aLong : ℕ → String
aLong n = fromList (replicate n 'a')

run : String → String → ℕ
run "read"       s = length (toList s)
run "tokenize"   s = lengthOf (tokenize (toList s))
run "parse"      s = orZero (tokenize (toList s) >>= λ ts → Maybe.map (λ _ → 1) (parseTokens ts))
run "json"       s = lengthOf (Maybe.map printJSON (parseJSON (toList s)))
run "extract"    s = withFeatures s length
run "convert"    s = withFeatures s (sumOver (λ f → weightOf (exactGeometry (Feature.geometry f))))
run "keepP"      s = withFeatures s (λ fs → keepWeight weightOf (map (λ f → exactGeometry (Feature.geometry f)) fs))
run "keepF"      s = withFeatures s (λ fs → keepFeatures (map (λ f → feature nothing (exactGeometry (Feature.geometry f)) $!′ Feature.properties f) fs))
run "keepE"      s = orZero (Maybe.map (λ fc → keepFeatures (applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc))
                                       (parseJSON (toList s) >>= extractLocatedFeatureCollection))
run "keepE2"     s = orZero (Maybe.map (λ fc → keepGeoms (applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc))
                                       (parseJSON (toList s) >>= extractLocatedFeatureCollection))
run "keepG"      s = withFeatures s (λ fs → keepWeight geomW (map Feature.geometry fs))
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

-- The loading chain of `exe/Earth` (`loadLayer`, `loadLayers`) on band files.
loadOne : String → IO (List Feature)
loadOne file =
  readFile file IO.>>= λ text →
  case parseJSON (toList text) of λ where
    nothing → IO.pure []
    (just json) →
      case extractLocatedFeatureCollection json of λ where
        nothing → IO.pure []
        (just fc) →
          let feats = applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc
          in putStrLn (NatShow.show (length feats + sumOver (λ f → weightOf (Feature.geometry f)) feats)) IO.>>
             IO.pure feats

-- the same, but forcing the whole properties list of each feature as it is loaded
loadProps : String → IO (List Feature)
loadProps file =
  readFile file IO.>>= λ text →
  case parseJSON (toList text) of λ where
    nothing → IO.pure []
    (just json) →
      case extractLocatedFeatureCollection json of λ where
        nothing → IO.pure []
        (just fc) →
          let feats = applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc
          in putStrLn (NatShow.show (length feats + sumOver (λ f → weightOf (Feature.geometry f) + length (Feature.properties f)) feats)) IO.>>
             IO.pure feats

loadAllProps : List String → IO (List Feature)
loadAllProps []        = IO.pure []
loadAllProps (f ∷ fs)  =
  loadProps f IO.>>= λ x →
  loadAllProps fs IO.>>= λ rest →
  IO.pure (x ++ rest)

-- the same, returning features with empty properties (geometry forced, source feature dropped)
loadG : String → IO (List Feature)
loadG file =
  readFile file IO.>>= λ text →
  case parseJSON (toList text) of λ where
    nothing → IO.pure []
    (just json) →
      case extractLocatedFeatureCollection json of λ where
        nothing → IO.pure []
        (just fc) →
          let feats = applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc
              bare  = map (λ f → (λ g → feature nothing g []) $!′ Feature.geometry f) feats
          in putStrLn (NatShow.show (length bare + sumOver (λ f → weightOf (Feature.geometry f) + length (Feature.properties f)) bare)) IO.>>
             IO.pure bare

loadAllG : List String → IO (List Feature)
loadAllG []        = IO.pure []
loadAllG (f ∷ fs)  =
  loadG f IO.>>= λ x →
  loadAllG fs IO.>>= λ rest →
  IO.pure (x ++ rest)

-- the same as `loadG`, but each path is rebuilt from its (forced) points, so nothing of the old path is kept
rebuildPath : Geometry → Geometry
rebuildPath (pathG p) = pathG (polygonP (pathRings p))
rebuildPath g         = g

loadC : String → IO (List Feature)
loadC file =
  readFile file IO.>>= λ text →
  case parseJSON (toList text) of λ where
    nothing → IO.pure []
    (just json) →
      case extractLocatedFeatureCollection json of λ where
        nothing → IO.pure []
        (just fc) →
          let feats = applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc
              bare  = map (λ f → (λ g → feature nothing (rebuildPath g) []) $!′ Feature.geometry f) feats
          in putStrLn (NatShow.show (length bare + sumOver (λ f → weightOf (Feature.geometry f)) bare)) IO.>>
             IO.pure bare

loadAccC : List String → List Feature → IO (List Feature)
loadAccC []        acc = IO.pure acc
loadAccC (f ∷ fs)  acc = loadC f IO.>>= λ x → loadAccC fs (x ++ acc)

-- the per-file work as one pure function, so the IO continuation sees only its result
convertFile : String → List Feature
convertFile text with parseJSON (toList text)
... | nothing   = []
... | just json with extractLocatedFeatureCollection json
...   | nothing = []
...   | just fc = applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc

loadF : String → IO (List Feature)
loadF file =
  readFile file IO.>>= λ text →
  let feats = convertFile text
  in putStrLn (NatShow.show (length feats + sumOver (λ f → weightOf (Feature.geometry f)) feats)) IO.>>
     IO.pure feats

loadFP : String → IO (List Feature)
loadFP file =
  readFile file IO.>>= λ text →
  let feats = convertFile text
  in putStrLn (NatShow.show (length feats + sumOver (λ f → weightOf (Feature.geometry f) + length (Feature.properties f)) feats)) IO.>>
     IO.pure feats

loadAccFP : List String → List Feature → IO (List Feature)
loadAccFP []        acc = IO.pure acc
loadAccFP (f ∷ fs)  acc = loadFP f IO.>>= λ x → loadAccFP fs (x ++ acc)

loadAccF : List String → List Feature → IO (List Feature)
loadAccF []        acc = IO.pure acc
loadAccF (f ∷ fs)  acc = loadF f IO.>>= λ x → loadAccF fs (x ++ acc)

-- tail-recursive accumulator version of the chain (no pending binds)
loadAcc : List String → List Feature → IO (List Feature)
loadAcc []        acc = IO.pure acc
loadAcc (f ∷ fs)  acc = loadG f IO.>>= λ x → loadAcc fs (x ++ acc)

-- the same, keeping nothing
loadNone : String → IO (List Feature)
loadNone file =
  readFile file IO.>>= λ text →
  case parseJSON (toList text) of λ where
    nothing → IO.pure []
    (just json) →
      case extractLocatedFeatureCollection json of λ where
        nothing → IO.pure []
        (just fc) →
          let feats = applyLayer (oceanBand (record defaultOptions { precision = 0 }) "" 1000) fc
          in putStrLn (NatShow.show (length feats + sumOver (λ f → weightOf (Feature.geometry f)) feats)) IO.>>
             IO.pure []

loadAllNone : List String → IO (List Feature)
loadAllNone []        = IO.pure []
loadAllNone (f ∷ fs)  =
  loadNone f IO.>>= λ x →
  loadAllNone fs IO.>>= λ rest →
  IO.pure (x ++ rest)

loadAll : List String → IO (List Feature)
loadAll []        = IO.pure []
loadAll (f ∷ fs)  =
  loadOne f IO.>>= λ x →
  loadAll fs IO.>>= λ rest →
  IO.pure (x ++ rest)

-- Render stages: the loaded features, then the SVG document built from them.
docOf : List Feature → _
docOf feats = renderMapSVG defaultTerrainStyle (featureCollection feats nothing)

-- the path text alone, no AST
pathChars : Feature → ℕ
pathChars f with Feature.geometry f
... | pathG p = length (renderPath equirectangular p)
... | _       = 0

-- the path text through a `String`, as the SVG attribute does
pathString : Feature → ℕ
pathString f with Feature.geometry f
... | pathG p = length (toList (fromList (renderPath equirectangular p)))
... | _       = 0

pathEsc : Feature → ℕ
pathEsc f with Feature.geometry f
... | pathG p = length (escapeValue (renderPath equirectangular p))
... | _       = 0

pathFix : Feature → ℕ
pathFix f with Feature.geometry f
... | pathG p = length (fixText (renderPath equirectangular p))
... | _       = 0

main : IO _
main = getArgs IO.>>= λ where
  ("renD" ∷ files) → loadAccF files [] IO.>>= λ feats →
      putStrLn (NatShow.show (sumOver pathChars feats))
  ("renE" ∷ files) → loadAccF files [] IO.>>= λ feats →
      putStrLn (NatShow.show (length (printTokens (docOf feats))))
  ("renF" ∷ files) → loadAccF files [] IO.>>= λ feats →
      putStrLn (NatShow.show (sumOver pathString feats))
  ("renG" ∷ files) → loadAccF files [] IO.>>= λ feats →
      putStrLn (NatShow.show (sumOver pathEsc feats))
  ("renH" ∷ files) → loadAccF files [] IO.>>= λ feats →
      putStrLn (NatShow.show (sumOver pathFix feats))
  ("renA" ∷ files) → loadAccF files [] IO.>>= λ feats →
      putStrLn (NatShow.show (length (printXML (docOf feats))))
  ("renB" ∷ files) → loadAccF files [] IO.>>= λ feats →
      let d = docOf feats in
      putStrLn (NatShow.show (length (printXML d))) IO.>>
      putStrLn (NatShow.show (length (printXML d)))
  ("renC" ∷ out ∷ files) → loadAccF files [] IO.>>= λ feats →
      writeFile out (fromList (printXML (docOf feats)))
  ("chainP" ∷ files) → loadAllProps files IO.>>= λ feats → putStrLn (NatShow.show (keepFeatures feats))
  ("chainG" ∷ files) → loadAllG files IO.>>= λ feats → putStrLn (NatShow.show (keepFeatures feats))
  ("chainA" ∷ files) → loadAcc files [] IO.>>= λ feats → putStrLn (NatShow.show (keepFeatures feats))
  ("chainC" ∷ files) → loadAccC files [] IO.>>= λ feats → putStrLn (NatShow.show (keepFeatures feats))
  ("chainF" ∷ files) → loadAccF files [] IO.>>= λ feats → putStrLn (NatShow.show (keepFeatures feats))
  ("chainFP" ∷ files) → loadAccFP files [] IO.>>= λ feats → putStrLn (NatShow.show (keepFeatures feats))
  ("chain0" ∷ files) → loadAllNone files IO.>>= λ feats → putStrLn (NatShow.show (length feats))
  ("chain" ∷ files) → loadAll files IO.>>= λ feats → putStrLn (NatShow.show (keepFeatures feats))
  (stage ∷ file ∷ _) → readFile file IO.>>= λ s → putStrLn (NatShow.show (run stage s))
  _ → putStrLn "usage: Profile <stage> <file>"
