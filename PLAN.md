# GeoAgda Implementation Plan & Roadmap

This document outlines the ordered implementation roadmap for **GeoAgda**, an Agda library for parsing, manipulating, and rendering map data, beginning with GeoJSON vector data from Natural Earth.

---

## Progress Overview

- [x] **Milestone 1: Container & Free Monad Formulations (JSON & XML/SVG ASTs)**
- [x] **Milestone 2: Invertible Parsing Framework & Lexical Combinators**
- [x] **Milestone 3: Structural JSON Parser & LeftInverse Soundness**
- [x] **Milestone 4: Schema Validation & Typed GeoJSON Extraction**
- [x] **Milestone 5: Catamorphic SVG Map Rendering Pipeline**
- [x] **Milestone 6: Fixture Validation & Natural Earth Vector Data Ingestion**

---

## Detailed Milestone Breakdown

### Milestone 1: Container & Free Monad Formulations (JSON & XML/SVG ASTs)
Establish the core algebraic foundation modeling hierarchical document ASTs as free monads over signatures.

- [x] **1.1 Workspace & Library Structure Setup**
  - [x] Configure `GeoAgda.agda-lib` linking `standard-library` and `agda-categories`.
  - [x] Establish `.agents/rules/guidelines.md` for hole-driven development and container conventions.
  - [x] Initialize `src/GeoAgda/` directory structure with base library index `src/GeoAgda.agda`.
- [x] **1.2 JSON Container Definition (`GeoAgda.Data.JSON.AST`)**
  - [x] Define `JSONShape` specifying the polynomial functor shapes:
    - Null, Boolean, Number (integral / rational representation), String literals.
    - Array node of length $n$ (`Fin n` positions).
    - Object node with field keys (`Fin n` positions indexed by key labels).
  - [x] Define `JSONPosition : JSONShape → Set` capturing arity and branching for each shape.
  - [x] Assemble `JSONContainer : Container 0ℓ 0ℓ`.
  - [x] Define `JSON : Set → Set` as `JSONContainer ⋆ X` using `Data.Container.FreeMonad`.
  - [x] Specialize `JSONValue = JSON ⊤` for standard closed JSON terms.
- [x] **1.3 JSON Catamorphisms & Serialization (`GeoAgda.Data.JSON.Print`)**
  - [x] Implement `foldJSON` via `Data.Container.FreeMonad.foldr`.
  - [x] Define `printJSON : JSONValue → List Char` as an algebra over `JSONContainer`.
- [x] **1.4 XML / SVG Container Definition (`GeoAgda.Data.XML.AST`)**
  - [x] Define `XMLShape` modeling text nodes, element tags, attributes (`List (String × String)`), and child arity $n$.
  - [x] Define `XMLPosition : XMLShape → Set` indexing child sub-elements.
  - [x] Form `XMLContainer : Container 0ℓ 0ℓ` and `XML = XMLContainer ⋆ X`.
  - [x] Define SVG element constructors (`svg`, `g`, `path`, `circle`, `polygon`, `polyline`, `rect`) as smart constructors over `XML ⊤`.
- [x] **1.5 XML / SVG Pretty Printing (`GeoAgda.Data.XML.Print`)**
  - [x] Define `printXML : XML ⊤ → List Char` using free monad catamorphism.


---

### Milestone 2: Invertible Parsing Framework & Lexical Combinators
Develop verified invertible parsing primitives modeled as explicit left inverses from `agda-stdlib`.

- [x] **2.1 Invertible Parsing Primitives (`GeoAgda.Parsing.Invertible.Core`)**
  - [x] Define the `InvertibleParser` record encapsulating `parse : I → Maybe (O × I)` and `print : O → I`, paired with left-inverse proofs.
  - [x] Formulate parsing as `LeftInverse` (`Function.Bundles.LeftInverse`) on successful prefixes.
  - [x] Implement identity, sequential composition (`_⨂_`), and alternative choice with stdlib preservation lemmas.
- [x] **2.2 Character & Digit Inverses (`GeoAgda.Parsing.Invertible.Char`)**
  - [x] Character classification and predicate filters (`Char.IsDigit`, `Char.IsWhitespace`).
  - [x] Prove `Fin 10 ↔ DigitChar` bijection.
- [x] **2.3 Numeric Invertible Conversions (`GeoAgda.Parsing.Invertible.Number`)**
  - [x] Natural number parsing `List (Fin 10) ↔ ℕ` with base-10 positional arithmetic lemmas.
  - [x] Integer parsing `Sign × ℕ ↔ ℤ`.
  - [x] Fixed-point / decimal fraction parsing for geographic coordinates (latitude / longitude).


---

### Milestone 3: Structural JSON Parser & LeftInverse Soundness
Assemble invertible combinators to construct the full JSON parser targeting `JSONContainer ⋆ ⊤`.

- [x] **3.1 Lexical Tokenizer (`GeoAgda.Parsing.JSON.Lexer`)**
  - [x] Define `JSONToken` (delimiters `{`, `}`, `[`, `]`, `:`, `,`, literals).
  - [x] Implement invertible whitespace stripping and tokenization.
- [x] **3.2 Recursive Tree Parser (`GeoAgda.Parsing.JSON.Parser`)**
  - [x] Define grammar for literals, arrays, and key-value objects using container shapes.
  - [x] Termination-checked recursive descent using fuel / sized types or list-length induction.
  - [x] Produce `parseJSON : List Char → Maybe JSONValue`.
- [x] **3.3 Soundness & Left-Inverse Round-Trip Verification**
  - [x] Prove `parseJSON (printJSON v) ≡ just v` for literals and flat structures.
  - [x] Formulate structural induction principle for `JSONContainer ⋆ ⊤` to extend round-trip proofs.


---

### Milestone 4: Schema Validation & Typed GeoJSON Extraction
Bridge untyped JSON free monads to strongly-typed GeoJSON domain models with verified decidable validation.

- [x] **4.1 Lightweight JSON Schema Language (`GeoAgda.Data.JSON.Schema`)**
  - [x] Define `Schema` data type (`sNull`, `sBool`, `sNumber`, `sString`, `sArray`, `sObject`).
  - [x] Define validation predicate `_⊨_ : JSONValue → Schema → Set`.
  - [x] Implement decidable checker `checkSchema : (v : JSONValue) (s : Schema) → Dec (v ⊨ s)`.
- [x] **4.2 Typed GeoJSON Domain Models (`GeoAgda.Model.GeoJSON.Types`)**
  - [x] `Position`: Longitude and Latitude pair with rational/integer representation (`JSONNumber`).
  - [x] `Geometry`:
    - `Point` (`Position`)
    - `MultiPoint` (`List Position`)
    - `LineString` (`List Position`)
    - `MultiLineString` (`List (List Position)`)
    - `Polygon` (`List (List Position)` - outer ring + inner rings)
    - `MultiPolygon` (`List (List (List Position))`)
    - `GeometryCollection` (`List Geometry`)
  - [x] `Feature`: Geometry + Properties (`List (String × JSONValue)`) + Optional ID.
  - [x] `FeatureCollection`: `List Feature` + optional bounding box (`BBox`).
- [x] **4.3 Schema-Driven Extractor (`GeoAgda.Model.GeoJSON.Extraction`)**
  - [x] Schemas for GeoJSON objects (`geoJsonSchema`, `geometrySchema`, `featureSchema`).
  - [x] Extraction functions converting validated `JSONValue` into typed `FeatureCollection`.
  - [x] Unit tests for geometry, feature, and feature collection extraction (`GeoAgda.Tests.Milestone4`).

---

### Milestone 5: Catamorphic SVG Map Rendering Pipeline
Transform typed GeoJSON vector data into the XML/SVG Free Monad for visualization.

- [x] **5.1 Coordinate Projections & Bounding Boxes (`GeoAgda.Rendering.SVG.Coordinates`)**
  - [x] Calculate bounding box `BBox` of geometries and feature collections.
  - [x] Implement standard cartographic projections:
    - Equirectangular (Plate Carrée): $(\lambda, \phi) \mapsto (x, y)$
  - [x] Affine coordinate formatting mapping projected coordinates into target SVG viewport / viewBox.
  - [x] Path formatting for SVG linear rings and polygons.
- [x] **5.2 SVG Geometry Catamorphisms (`GeoAgda.Rendering.SVG.Render`)**
  - [x] Geometry-to-SVG catamorphism:
    - `Point` $\mapsto$ `<circle cx=... cy=... r=... />`
    - `LineString` $\mapsto$ `<polyline points=... />`
    - `Polygon` $\mapsto$ `<path d=... fill-rule="evenodd" />`
    - `MultiPoint`, `MultiLineString`, `MultiPolygon`, `GeometryCollection` $\mapsto$ `<g> ... </g>`
  - [x] Feature styling: apply fill, stroke, stroke-width, and opacity attributes.
  - [x] Assemble full SVG root `<svg xmlns="http://www.w3.org/2000/svg" viewBox="..."> ... </svg>` as `XML ⊤`.
  - [x] Unit tests for SVG rendering pipeline (`GeoAgda.Tests.Milestone5`).

---

### Milestone 6: Fixture Validation & Natural Earth Vector Data Ingestion
Validate end-to-end functionality against real-world vector fixtures.

- [x] **6.1 Unit & Fixture Tests (`GeoAgda.Tests.Fixtures`)**
  - [x] Test Fixture 1: Simple GeoJSON `Point` (`data/fixtures/point.geojson`).
  - [x] Test Fixture 2: GeoJSON `Polygon` (`data/fixtures/polygon.geojson`).
  - [x] Test Fixture 3: `FeatureCollection` with multiple features and properties.
  - [x] Verify parse $\to$ extract $\to$ render $\to$ serialize pipeline end-to-end at compile time via `refl`.
- [x] **6.2 Natural Earth Dataset Ingestion**
  - [x] Ingestion fixture representing Natural Earth 110m country vector boundary (`data/fixtures/natural_earth_sample.geojson`).
  - [x] High-level pipeline API in `GeoAgda.Pipeline` (`geojsonStringToSVG`, `geojsonCharsToSVG`, `geojsonDocToSVG`).
  - [x] Verify complete pipeline rendering into valid SVG output files and compile-time proofs.
