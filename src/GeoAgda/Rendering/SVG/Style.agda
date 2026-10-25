{-# OPTIONS --safe --cubical-compatible -WnoUnsupportedIndexedMatch #-}

module GeoAgda.Rendering.SVG.Style where

open import Data.Bool using (Bool; true; false)
open import Data.String using (String)
open import Data.List using ([]; _∷_)
open import Data.Product using (_,_)
open import Data.Maybe using (Maybe; just; nothing)

open import Data.SVG using (Attrs)

------------------------------------------------------------------------
-- SVG Styling Configuration
------------------------------------------------------------------------

record SVGStyle : Set where
  constructor svgStyle
  field
    fill               : Maybe String
    stroke             : Maybe String
    strokeWidth        : Maybe String
    opacity            : Maybe String
    pointRadius        : String
    oceanFill          : Maybe String
    useTerrainColors   : Bool
    renderLabels       : Bool
    topLevelLabelsOnly : Bool
    labelFontSize      : String
    labelColor         : String

defaultPointStyle : SVGStyle
defaultPointStyle = svgStyle (just "#e41a1c") (just "#333333") (just "1") nothing "4" nothing false true false "3.0" "#111111"

defaultPolygonStyle : SVGStyle
defaultPolygonStyle = svgStyle (just "#4daf4a") (just "#333333") (just "0.05") (just "0.8") "3" nothing false false false "2.8" "#2b231d"

defaultTerrainStyle : SVGStyle
defaultTerrainStyle = svgStyle (just "#a8cca0") (just "#7d7565") (just "0.15") (just "0.95") "3" (just "#092244") true true true "1.2" "#222222"

------------------------------------------------------------------------
-- Style updates
------------------------------------------------------------------------

-- Set fill colour, stroke colour and stroke width.
paint : (fill stroke width : String) → SVGStyle → SVGStyle
paint f st w s = record s { fill = just f ; stroke = just st ; strokeWidth = just w }

-- Unfilled outline: fill "none".
outline : (stroke width : String) → SVGStyle → SVGStyle
outline = paint "none"

-- Same colour for fill and stroke.
solid : (colour width : String) → SVGStyle → SVGStyle
solid c = paint c c

------------------------------------------------------------------------
-- Presentation attributes
------------------------------------------------------------------------

styleToAttrs : SVGStyle → Attrs
styleToAttrs s =
  addAttr "fill" (SVGStyle.fill s)
    (addAttr "stroke" (SVGStyle.stroke s)
      (addAttr "stroke-width" (SVGStyle.strokeWidth s)
        (addAttr "opacity" (SVGStyle.opacity s) [])))
  where
    addAttr : String → Maybe String → Attrs → Attrs
    addAttr key nothing  acc = acc
    addAttr key (just v) acc = (key , v) ∷ acc
