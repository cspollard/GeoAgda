{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- Label anchor positions: centroids of geometries and features.
module GeoAgda.Rendering.SVG.Centroid where

open import Data.Integer as ℤ using (ℤ)
open import Data.List using (List; []; _∷_; concat; map)
open import Data.Product using (_×_; _,_)
open import Data.Maybe using (Maybe; just; nothing; _>>=_)
open import Function using (_∘_)

open import Data.JSON.Schema using (lookupField; asNumber)
open import GeoAgda.Model.Exact using (fromExactPt)
open import GeoAgda.Model.GeoJSON.Types
open import GeoAgda.Model.Path using (pathRings)
open import GeoAgda.Rendering.SVG.Scaled

positionsBBoxScaled : List Position → Maybe (ℤ × ℤ × ℤ × ℤ)
positionsBBoxScaled [] = nothing
positionsBBoxScaled (p ∷ ps) =
  let x = jsonNumberToScaledℤ (Position.lon p)
      y = jsonNumberToScaledℤ (Position.lat p)
  in just (go x y x y ps)
  where
    go : ℤ → ℤ → ℤ → ℤ → List Position → (ℤ × ℤ × ℤ × ℤ)
    go minX minY maxX maxY [] = minX , minY , maxX , maxY
    go minX minY maxX maxY (p ∷ ps) =
      let px = jsonNumberToScaledℤ (Position.lon p)
          py = jsonNumberToScaledℤ (Position.lat p)
      in go (minℤ minX px) (minℤ minY py) (maxℤ maxX px) (maxℤ maxY py) ps

bboxCenter : (ℤ × ℤ × ℤ × ℤ) → Position
bboxCenter (minX , minY , maxX , maxY) =
  pos (scaledℤToJSONNumber (halfℤ (minX ℤ.+ maxX)))
      (scaledℤToJSONNumber (halfℤ (minY ℤ.+ maxY)))

geometryCentroid : Geometry → Maybe Position
geometryCentroid (pointG p)                       = just p
geometryCentroid (multiPointG ps)                 = positionsBBoxScaled ps >>= (just ∘ bboxCenter)
geometryCentroid (lineStringG ps)                 = positionsBBoxScaled ps >>= (just ∘ bboxCenter)
geometryCentroid (multiLineStringG pss)           = positionsBBoxScaled (concat pss) >>= (just ∘ bboxCenter)
geometryCentroid (polygonG [])                    = nothing
geometryCentroid (polygonG (ring ∷ _))             = positionsBBoxScaled ring >>= (just ∘ bboxCenter)
geometryCentroid (pathG p) with pathRings p
... | []         = nothing
... | ring ∷ _   = positionsBBoxScaled (map fromExactPt ring) >>= (just ∘ bboxCenter)
geometryCentroid (multiPolygonG [])               = nothing
geometryCentroid (multiPolygonG ((ring ∷ _) ∷ _)) = positionsBBoxScaled ring >>= (just ∘ bboxCenter)
geometryCentroid (multiPolygonG ([] ∷ ps))        = geometryCentroid (multiPolygonG ps)
geometryCentroid (geometryCollectionG [])         = nothing
geometryCentroid (geometryCollectionG (g ∷ _))     = geometryCentroid g

featureCentroid : Feature → Maybe Position
featureCentroid (feature _ geom props) with lookupField "LABELX" props >>= asNumber | lookupField "LABELY" props >>= asNumber
... | just lx | just ly = just (pos lx ly)
... | _       | _       with lookupField "long_x" props >>= asNumber | lookupField "lat_y" props >>= asNumber
...   | just lx | just ly = just (pos lx ly)
...   | _       | _       = geometryCentroid geom
