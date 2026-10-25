{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

-- What the earth map shows and how much detail it keeps, plus the parser
-- for the `Earth` command line.
module GeoAgda.Compose.Options where

open import Data.Bool using (Bool; true; false; not; if_then_else_)
open import Data.Char using (Char; isDigit; _≈ᵇ_; toℕ)
open import Data.List as List using (List; []; _∷_; foldl; length; replicate; _++_; spanᵇ)
open import Data.Maybe using (Maybe; just; nothing)
open import Data.Nat using (ℕ; suc; _+_; _*_; _∸_; _≤ᵇ_)
open import Data.Product using (_×_; _,_)
open import Data.String as String using (String; toList; fromList) renaming (_++_ to _++ˢ_)
open import Data.String.Properties using (_==_)
open import Data.Sum using (_⊎_; inj₁; inj₂)

-- How land is shaded.
data LandMode : Set where
  elevation : LandMode   -- shades of green by elevation
  flat      : LandMode   -- one colour: no elevation
  areas     : LandMode   -- named areas of interest and peaks, hypsometric tints

-- Which Natural Earth scale the land, water, border and label layers come from.
data Resolution : Set where
  res10m res50m res110m : Resolution

-- Lengths are in units of 10⁻⁴ degrees.
record Options : Set where
  constructor options
  field
    land         : LandMode
    borders      : Bool   -- country boundary lines
    countryNames : Bool   -- country name labels
    precision    : ℕ      -- coordinates are rounded to a multiple of this; 0: geometry is kept exactly as read
    thinning     : ℕ      -- bathymetry vertices are kept ≥ this far apart (0: no thinning)
    resolution   : Resolution

defaultOptions : Options
defaultOptions = options elevation false false 100 3000 res10m

record Invocation : Set where
  constructor invocation
  field
    opts    : Options
    dataDir : String
    output  : String

defaultInvocation : Invocation
defaultInvocation = invocation defaultOptions "natural-earth-geojson" "earth.svg"

usage : String
usage = "usage: Earth [options] [data-dir [out.svg]]\n\
  \  --land=elevation|flat|areas  how land is shaded (default elevation)\n\
  \       elevation: shades of green by elevation; flat: one colour;\n\
  \       areas: named plains, deserts and ranges, peaks and their labels\n\
  \  --resolution=10m|50m|110m   source scale of land, lakes, rivers, borders and\n\
  \                               country names (default 10m, matching the bathymetry)\n\
  \  --borders                    draw country boundaries\n\
  \  --country-names              label countries\n\
  \  --precision=DEGREES          round coordinates to this grid (default 0.01);\n\
  \                               0 keeps every vertex as read, ignoring --thin\n\
  \  --thin=DEGREES               thin bathymetry vertices closer than this\n\
  \                               (default 0.3; 0 keeps them all)"

------------------------------------------------------------------------
-- Parsing
------------------------------------------------------------------------

private
  _>>=ᴹ_ : ∀ {A B : Set} → Maybe A → (A → Maybe B) → Maybe B
  nothing >>=ᴹ k = nothing
  just a  >>=ᴹ k = k a

  allDigits : List Char → Bool
  allDigits []       = true
  allDigits (c ∷ cs) = if isDigit c then allDigits cs else false

  digits : List Char → Maybe ℕ
  digits cs = if allDigits cs then just (foldl (λ acc c → acc * 10 + (toℕ c ∸ 48)) 0 cs) else nothing

-- Decimal degrees ("0.01", "3", ".5") as a multiple of 10⁻⁴°; at most four decimals.
parseDegrees : String → Maybe ℕ
parseDegrees s with spanᵇ (λ c → not (c ≈ᵇ '.')) (toList s)
... | whole , [] = digits whole >>=ᴹ λ w → just (w * 10000)
... | whole , _ ∷ frac =
  digits whole >>=ᴹ λ w →
  (if length frac ≤ᵇ 4 then digits (frac ++ replicate (4 ∸ length frac) '0') else nothing) >>=ᴹ λ f →
  just (w * 10000 + f)

private
  updateOpts : (Options → Options) → Invocation → Invocation
  updateOpts f inv = record inv { opts = f (Invocation.opts inv) }

  setLand : LandMode → Invocation → Invocation
  setLand v = updateOpts λ o → record o { land = v }

  setResolution : Resolution → Invocation → Invocation
  setResolution v = updateOpts λ o → record o { resolution = v }

  setBorders setNames : Bool → Invocation → Invocation
  setBorders v = updateOpts λ o → record o { borders = v }
  setNames   v = updateOpts λ o → record o { countryNames = v }

  setPrecision setThinning : ℕ → Invocation → Invocation
  setPrecision v = updateOpts λ o → record o { precision = v }
  setThinning  v = updateOpts λ o → record o { thinning = v }

  setDir setOut : String → Invocation → Invocation
  setDir v inv = record inv { dataDir = v }
  setOut v inv = record inv { output = v }

  -- "--key=value" ↦ (key , just value); "--key" ↦ (key , nothing)
  splitFlag : String → String × Maybe String
  splitFlag a with spanᵇ (λ c → not (c ≈ᵇ '=')) (toList a)
  ... | k , []      = fromList k , nothing
  ... | k , _ ∷ v   = fromList k , just (fromList v)

  flagValue : String → Maybe String → (String → Maybe (Invocation → Invocation))
              → String ⊎ (Invocation → Invocation)
  flagValue name nothing  _ = inj₁ (name ++ˢ " needs a value")
  flagValue name (just v) f with f v
  ... | just u  = inj₂ u
  ... | nothing = inj₁ ("bad value for " ++ˢ name ++ˢ ": " ++ˢ v)

  parseLand : String → Maybe LandMode
  parseLand v =
    if v == "elevation" then just elevation else
    if v == "flat"      then just flat else
    if v == "areas"     then just areas else nothing

  parseResolution : String → Maybe Resolution
  parseResolution v =
    if v == "10m"  then just res10m else
    if v == "50m"  then just res50m else
    if v == "110m" then just res110m else nothing

  parseFlag : String → Maybe String → String ⊎ (Invocation → Invocation)
  parseFlag k v =
    if k == "--land"          then flagValue k v (λ x → parseLand x >>=ᴹ λ m → just (setLand m)) else
    if k == "--resolution"    then flagValue k v (λ x → parseResolution x >>=ᴹ λ r → just (setResolution r)) else
    if k == "--borders"       then inj₂ (setBorders true) else
    if k == "--country-names" then inj₂ (setNames true) else
    if k == "--precision"     then flagValue k v (λ x → parseDegrees x >>=ᴹ λ n → just (setPrecision n)) else
    if k == "--thin"          then flagValue k v (λ x → parseDegrees x >>=ᴹ λ n → just (setThinning n)) else
    inj₁ ("unknown option " ++ˢ k)

  isFlag : String → Bool
  isFlag a with toList a
  ... | '-' ∷ '-' ∷ _ = true
  ... | _             = false

-- Options may be mixed with the (up to two) positional arguments.
parseArgs : List String → String ⊎ Invocation
parseArgs = go defaultInvocation 0
  where
    positional : ℕ → String → Invocation → Maybe Invocation
    positional 0 a inv = just (setDir a inv)
    positional 1 a inv = just (setOut a inv)
    positional _ _ _   = nothing

    go : Invocation → ℕ → List String → String ⊎ Invocation
    go inv _ [] = inj₂ inv
    go inv n (a ∷ as) with isFlag a
    ... | true  with splitFlag a
    ...   | k , v with parseFlag k v
    ...     | inj₁ err = inj₁ err
    ...     | inj₂ u   = go (u inv) n as
    go inv n (a ∷ as) | false with positional n a inv
    ... | just inv′ = go inv′ (suc n) as
    ... | nothing   = inj₁ ("unexpected argument " ++ˢ a)
