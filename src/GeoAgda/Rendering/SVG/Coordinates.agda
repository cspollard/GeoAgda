{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Rendering.SVG.Coordinates where

open import Level using (0ℓ)
open import Data.Bool using (Bool; true; false; if_then_else_)
open import Data.Char using (Char)
open import Data.String as String using (String; toList; fromList)
open import Data.Nat as ℕ using (ℕ; zero; suc; _*_; _/_; _%_) renaming (_+_ to _+ℕ_)
import Data.Nat.Show as NatShow
open import Data.Integer as ℤ using (ℤ; +_; -[1+_]; 0ℤ; _-_; ∣_∣; _+_; _⊓_; _⊔_)
open import Data.Sign using (Sign; +; -)
open import Data.Fin as Fin using (Fin)
open import Data.List as List using (List; []; _∷_; _++_; concat; map; intersperse)
open import Data.Product using (_×_; _,_; proj₁; proj₂)
open import Data.Maybe using (Maybe; just; nothing; _>>=_)
open import Function using (_∘_; _$_)

open import GeoAgda.Data.JSON.AST using (JSONNumber; jsonNumber)
open import GeoAgda.Data.JSON.Print using (printNumber)
open import GeoAgda.Data.JSON.Schema using (lookupField; asNumber)
open import GeoAgda.Model.GeoJSON.Types
  using (Position; pos; BBox; bbox; Geometry; pointG; multiPointG; lineStringG;
         multiLineStringG; polygonG; multiPolygonG; geometryCollectionG;
         Feature; feature; Properties)
open import GeoAgda.Parsing.Invertible.Number using (signNatToℤ)


------------------------------------------------------------------------
-- Number Formatting and Sign Manipulation
------------------------------------------------------------------------

oppositeSign : Sign → Sign
oppositeSign + = -
oppositeSign - = +

negateJSONNumber : JSONNumber → JSONNumber
negateJSONNumber (jsonNumber sign integral fraction exponent) =
  jsonNumber (oppositeSign sign) integral fraction exponent

renderJSONNumber : JSONNumber → String
renderJSONNumber = fromList ∘ printNumber

------------------------------------------------------------------------
-- Projected Points & Projections
------------------------------------------------------------------------

record ProjectedPoint : Set where
  constructor projPt
  field
    x : String
    y : String

Projection : Set
Projection = Position → ProjectedPoint

-- Standard Equirectangular (Plate Carrée) projection
-- Longitude maps directly to x; Latitude is inverted (y = -lat)
-- because SVG y-coordinates increase downwards.
equirectangular : Projection
equirectangular (pos lon lat) =
  projPt (renderJSONNumber lon) (renderJSONNumber (negateJSONNumber lat))

------------------------------------------------------------------------
-- Formatting Points for SVG Attributes
------------------------------------------------------------------------

-- Format a single projected point as "x,y"
formatPointPair : ProjectedPoint → List Char
formatPointPair (projPt x y) = toList x ++ (',' ∷ toList y)

-- Format a list of positions as SVG points attribute: "x1,y1 x2,y2 ..."
formatPointsList : Projection → List Position → List Char
formatPointsList proj pts =
  concat (intersperse (' ' ∷ []) (map (formatPointPair ∘ proj) pts))

formatPoints : Projection → List Position → String
formatPoints proj pts = fromList (formatPointsList proj pts)

------------------------------------------------------------------------
-- Formatting SVG Path Data ("d" attribute)
------------------------------------------------------------------------

private
  formatPathLines : Projection → List Position → List Char
  formatPathLines proj []       = []
  formatPathLines proj (p ∷ ps) =
    ' ' ∷ 'L' ∷ ' ' ∷ formatPointPair (proj p) ++ formatPathLines proj ps

-- Formats a closed linear ring as "M x0 y0 L x1 y1 ... Z"
formatRingD : Projection → List Position → List Char
formatRingD proj []       = []
formatRingD proj (p ∷ ps) =
  'M' ∷ ' ' ∷ formatPointPair (proj p) ++ formatPathLines proj ps ++ (' ' ∷ 'Z' ∷ [])

-- Formats a polygon (outer ring + inner rings) into path data
formatPolygonD : Projection → List (List Position) → String
formatPolygonD proj rings =
  fromList (concat (intersperse (' ' ∷ []) (map (formatRingD proj) rings)))

-- Formats a multi-polygon into path data
formatMultiPolygonD : Projection → List (List (List Position)) → String
formatMultiPolygonD proj polys =
  fromList (concat (intersperse (' ' ∷ []) (map (toList ∘ formatPolygonD proj) polys)))

------------------------------------------------------------------------
-- ViewBox Formatting & Dimension Calculations
------------------------------------------------------------------------

-- Format standard SVG viewBox attribute "minX minY width height"
formatViewBox : (minX minY width height : String) → String
formatViewBox minX minY w h =
  String._++_ minX (String._++_ " " (String._++_ minY (String._++_ " " (String._++_ w (String._++_ " " h)))))

-- Default world viewBox spanning -180 to 180 lon and -90 to 90 lat
defaultWorldViewBox : String
defaultWorldViewBox = formatViewBox "-180" "-90" "360" "180"

-- Convert JSONNumber to scaled integer (scaling fraction by factor of 10000)
scaleFraction : List (Fin 10) → ℕ
scaleFraction []                       = 0
scaleFraction (d₁ ∷ [])                 = Fin.toℕ d₁ * 1000
scaleFraction (d₁ ∷ d₂ ∷ [])             = (Fin.toℕ d₁ * 1000) +ℕ (Fin.toℕ d₂ * 100)
scaleFraction (d₁ ∷ d₂ ∷ d₃ ∷ [])         = (Fin.toℕ d₁ * 1000) +ℕ (Fin.toℕ d₂ * 100) +ℕ (Fin.toℕ d₃ * 10)
scaleFraction (d₁ ∷ d₂ ∷ d₃ ∷ d₄ ∷ _)     = (Fin.toℕ d₁ * 1000) +ℕ (Fin.toℕ d₂ * 100) +ℕ (Fin.toℕ d₃ * 10) +ℕ Fin.toℕ d₄

jsonNumberToScaledℤ : JSONNumber → ℤ
jsonNumberToScaledℤ (jsonNumber sign integral fraction _) =
  signNatToℤ sign ((integral * 10000) +ℕ scaleFraction fraction)

formatScaledDiff : ℕ → String
formatScaledDiff diffℕ =
  let intPart = diffℕ / 10000
      fracPart = (diffℕ % 10000) / 100
  in case fracPart of λ where
       zero    → NatShow.show intPart
       (suc _) → String._++_ (NatShow.show intPart) (String._++_ "." (NatShow.show fracPart))
  where
    case_of_ : ∀ {A B : Set} → A → (A → B) → B
    case x of f = f x

computePositiveDiff : JSONNumber → JSONNumber → String
computePositiveDiff n₁ n₂ =
  let v₁ = jsonNumberToScaledℤ n₁
      v₂ = jsonNumberToScaledℤ n₂
      diffℤ = v₂ ℤ.- v₁
  in formatScaledDiff (ℤ.∣ diffℤ ∣)

record ViewBox : Set where
  constructor viewBox
  field
    minX   : String
    minY   : String
    width  : String
    height : String

viewBoxToString : ViewBox → String
viewBoxToString (viewBox minX minY w h) = formatViewBox minX minY w h

defaultWorldViewBoxRec : ViewBox
defaultWorldViewBoxRec = viewBox "-180" "-90" "360" "180"

-- Format viewBox from a GeoJSON BBox under equirectangular projection
viewBoxComponentsFromBBox : BBox → ViewBox
viewBoxComponentsFromBBox (bbox minLon minLat maxLon maxLat) =
  viewBox
    (renderJSONNumber minLon)
    (renderJSONNumber (negateJSONNumber maxLat))
    (computePositiveDiff minLon maxLon)
    (computePositiveDiff minLat maxLat)

viewBoxFromBBox : BBox → String
viewBoxFromBBox bb = viewBoxToString (viewBoxComponentsFromBBox bb)

------------------------------------------------------------------------
-- Geometry & Feature Centroid Extraction
------------------------------------------------------------------------

natToFin10 : ℕ → Fin 10
natToFin10 zero                                                 = Fin.zero
natToFin10 (suc zero)                                           = Fin.suc Fin.zero
natToFin10 (suc (suc zero))                                     = Fin.suc (Fin.suc Fin.zero)
natToFin10 (suc (suc (suc zero)))                               = Fin.suc (Fin.suc (Fin.suc Fin.zero))
natToFin10 (suc (suc (suc (suc zero))))                         = Fin.suc (Fin.suc (Fin.suc (Fin.suc Fin.zero)))
natToFin10 (suc (suc (suc (suc (suc zero)))))                   = Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc Fin.zero))))
natToFin10 (suc (suc (suc (suc (suc (suc zero))))))             = Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc Fin.zero)))))
natToFin10 (suc (suc (suc (suc (suc (suc (suc zero)))))))       = Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc Fin.zero))))))
natToFin10 (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))) = Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc Fin.zero)))))))
natToFin10 _                                                   = Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc (Fin.suc Fin.zero))))))))

halfℤ : ℤ → ℤ
halfℤ (+_ n)   = +_ (n / 2)
halfℤ -[1+ n ] = -[1+ (n / 2) ]

scaledℤToJSONNumber : ℤ → JSONNumber
scaledℤToJSONNumber (+_ n) =
  let intPart = n / 10000
      rem     = n % 10000
      d₁      = natToFin10 ((rem / 1000) % 10)
      d₂      = natToFin10 ((rem / 100) % 10)
  in jsonNumber Sign.+ intPart (d₁ ∷ d₂ ∷ []) (+_ 0)
scaledℤToJSONNumber -[1+ n ] =
  let m       = suc n
      intPart = m / 10000
      rem     = m % 10000
      d₁      = natToFin10 ((rem / 1000) % 10)
      d₂      = natToFin10 ((rem / 100) % 10)
  in jsonNumber Sign.- intPart (d₁ ∷ d₂ ∷ []) (+_ 0)



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
      in go (minX ℤ.⊓ px) (minY ℤ.⊓ py) (maxX ℤ.⊔ px) (maxY ℤ.⊔ py) ps

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

