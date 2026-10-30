{-# OPTIONS --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- `Earth [options] [data-dir [out.svg]]`: compose the earth-with-elevation map from the
-- Natural Earth GeoJSON files in `data-dir` (default `natural-earth-geojson`)
-- and write it as SVG (default `earth.svg`).  `Earth --help` lists the options
-- (land shading, country boundaries and names, level of detail).
--
-- Each layer is read, parsed, reduced and fully evaluated before the next file
-- is read, so peak memory is that of the largest single input.
module Earth where

open import Agda.Builtin.IO using (IO)
open import Agda.Builtin.Unit using (tt) renaming (⊤ to Unit)
open import Data.List as List using (List; []; _∷_; _++_; length; map; foldl)
open import Data.Maybe using (just; nothing)
open import Data.Nat using (ℕ; _+_)
open import Data.Nat.Show using (show)
open import Data.String as String using (String; toList) renaming (_++_ to _++ˢ_)
open import Data.Sum using (_⊎_; inj₁; inj₂)
open import Function using (case_of_)
open import IO.Primitive.Core using (pure; _>>=_; _>>_)
open import IO.Primitive.Finite using (readFile; writeFile; appendFile; putStrLn)
open import System.Environment.Primitive using (getArgs)

open import Data.JSON.AST using (jsonNumber)
open import Data.JSON.RoundTrip using (parseJSON)
open import Data.XML.Chunks using (xmlChunks)
open import GeoAgda.Compose
open import GeoAgda.Compose.Earth using (earthRecipe; earthStyle)
open import GeoAgda.Compose.Options
open import GeoAgda.Model.GeoJSON.Extraction using (extractLocatedFeatureCollection)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.Path using (pathWeight)
open import GeoAgda.Rendering.SVG.Render using (renderMapSVG)

say : String → IO Unit
say msg = putStrLn ("[Earth] " ++ˢ msg)

------------------------------------------------------------------------
-- Forcing
------------------------------------------------------------------------

-- A number that depends on every vertex, so that printing it forces the
-- features and lets the source AST be collected.
weight : List Feature → ℕ
weight = foldl (λ acc f → acc + geomWeight (Feature.geometry f)) 0
  where
    posW : Position → ℕ
    posW (pos (jsonNumber _ a _ _) (jsonNumber _ b _ _)) = a + b + 1

    posesW : List Position → ℕ
    posesW = foldl (λ acc p → acc + posW p) 0

    ringsW : List (List Position) → ℕ
    ringsW = foldl (λ acc r → acc + posesW r) 0

    geomWeight : Geometry → ℕ
    geomWeight (pointG p)             = posW p
    geomWeight (multiPointG ps)       = posesW ps
    geomWeight (lineStringG ps)       = posesW ps
    geomWeight (multiLineStringG ls)  = ringsW ls
    geomWeight (polygonG rs)          = ringsW rs
    geomWeight (multiPolygonG ps)     = foldl (λ acc rs → acc + ringsW rs) 0 ps
    geomWeight (geometryCollectionG _) = 0
    geomWeight (pathG p)              = pathWeight p

------------------------------------------------------------------------
-- Loading
------------------------------------------------------------------------

-- The features of one layer file, or why there are none.  This is a pure function of the file's text, so
-- the IO step below sees only its (forced) result: with the parse and the extracted collection in scope of
-- the IO continuation instead, every loaded file's source stayed alive until the whole load finished.
convertText : Layer → String → String ⊎ List Feature
convertText l text with parseJSON (toList text)
... | nothing   = inj₁ "cannot parse "
... | just json with extractLocatedFeatureCollection json
...   | nothing = inj₁ "not a feature collection: "
...   | just fc = inj₂ (applyLayer l fc)

loadLayer : String → Layer → IO (List Feature)
loadLayer dir l =
  readFile file >>= λ text →
  case convertText l text of λ where
    (inj₁ why)   → say (why ++ˢ file) >> pure []
    (inj₂ feats) →
      say (Layer.path l ++ˢ ": " ++ˢ show (length feats) ++ˢ " features, weight "
           ++ˢ show (weight feats)) >>
      pure feats
  where file = layerFile dir l

loadLayers : String → List Layer → IO (List Feature)
loadLayers dir []        = pure []
loadLayers dir (l ∷ ls)  =
  loadLayer dir l >>= λ fs →
  loadLayers dir ls >>= λ rest →
  pure (fs ++ rest)

loadGroup : String → Group → IO (List Feature)
loadGroup dir g = loadLayers dir (Group.layers g) >>= λ fs → pure (Group.finish g fs)

loadRecipe : String → Recipe → IO (List Feature)
loadRecipe dir []        = pure []
loadRecipe dir (g ∷ gs)  =
  loadGroup dir g >>= λ fs →
  loadRecipe dir gs >>= λ rest →
  pure (fs ++ rest)

-- Write the chunks one after the other; each is dropped once written, so the
-- whole document is never in memory as text.
writeChunks : String → List String → IO Unit
writeChunks out []       = pure tt
writeChunks out (c ∷ cs) = appendFile out c >> writeChunks out cs

build : Invocation → IO Unit
build (invocation o dir out) =
  say ("Reading Natural Earth data from " ++ˢ dir) >>
  (loadRecipe dir (earthRecipe o) >>= λ feats →
   say ("Composed " ++ˢ show (length feats) ++ˢ " features; rendering") >>
   (writeFile out "" >>
    (writeChunks out (xmlChunks (renderMapSVG (earthStyle o) (featureCollection feats nothing))) >>
     say ("Wrote " ++ˢ out))))

main : IO Unit
main = getArgs >>= λ args → case args of λ where
  ("--help" ∷ _) → putStrLn usage
  _ → case parseArgs args of λ where
    (inj₁ err) → say err >> putStrLn usage
    (inj₂ inv) → build inv
