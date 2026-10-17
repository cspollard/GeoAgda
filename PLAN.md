# GeoAgda Implementation Plan & Roadmap

This document outlines the ordered implementation roadmap for **GeoAgda**, an Agda library for parsing, manipulating, and rendering map data, beginning with GeoJSON vector data from Natural Earth.

---

## Progress Overview

- [x] **Milestone 1: Container & Free Monad Formulations (JSON & XML/SVG ASTs)**
- [x] **Milestone 2: Invertible Parsing Framework & Lexical Combinators**
- [x] **Milestone 3: Structural JSON Parser & LeftInverse Soundness**
- [ ] **Milestone 4: Schema Validation & Typed GeoJSON Extraction**
- [ ] **Milestone 5: Catamorphic SVG Map Rendering Pipeline**
- [ ] **Milestone 6: Fixture Validation & Natural Earth Vector Data Ingestion**

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

- [ ] **4.1 Lightweight JSON Schema Language (`GeoAgda.Data.JSON.Schema`)**
  - [ ] Define `Schema` data type (`sNull`, `sBool`, `sNumber`, `sString`, `sArray`, `sObject`).
  - [ ] Define validation predicate `_⊨_ : JSONValue → Schema → Set`.
  - [ ] Implement decidable checker `checkSchema : (v : JSONValue) (s : Schema) → Dec (v ⊨ s)`.
- [ ] **4.2 Typed GeoJSON Domain Models (`GeoAgda.Model.GeoJSON.Types`)**
  - [ ] `Position`: Longitude and Latitude pair with bound proofs ($-180 \le \lambda \le 180$, $-90 \le \phi \le 90$) or rational representations.
  - [ ] `Geometry`:
    - `Point` (`Position`)
    - `MultiPoint` (`List Position`)
    - `LineString` (`List Position`)
    - `MultiLineString` (`List (List Position)`)
    - `Polygon` (`List (List Position)` - outer ring + inner rings)
    - `MultiPolygon` (`List (List (List Position))`)
    - `GeometryCollection` (`List Geometry`)
  - [ ] `Feature`: Geometry + Properties (`List (String × JSONValue)`) + Optional ID.
  - [ ] `FeatureCollection`: `List Feature` + optional bounding box (`BBox`).
- [ ] **4.3 Schema-Driven Extractor (`GeoAgda.Model.GeoJSON.Extraction`)**
  - [ ] Schemas for GeoJSON objects (`geoJsonSchema`, `geometrySchema`, `featureSchema`).
  - [ ] Extraction functions converting validated `JSONValue` into typed `FeatureCollection`.
  - [ ] Proof of extraction soundness: successful extraction yields valid geometries.

---

### Milestone 5: Catamorphic SVG Map Rendering Pipeline
Transform typed GeoJSON vector data into the XML/SVG Free Monad for visualization.

- [ ] **5.1 Coordinate Projections & Bounding Boxes (`GeoAgda.Rendering.SVG.Coordinates`)**
  - [ ] Calculate bounding box `BBox` of geometries and feature collections.
  - [ ] Implement standard cartographic projections:
    - Equirectangular (Plate Carrée): $(\lambda, \phi) \mapsto (x, y)$
    - Web Mercator projection.
  - [ ] Affine transformations mapping projected coordinates into target SVG viewport / viewBox.
- [ ] **5.2 SVG Geometry Catamorphisms (`GeoAgda.Rendering.SVG.Render`)**
  - [ ] Geometry-to-SVG catamorphism:
    - `Point` $\mapsto$ `<circle cx=... cy=... r=... />`
    - `LineString` $\mapsto$ `<polyline points=... />` or `<path d=... />`
    - `Polygon` $\mapsto$ `<polygon points=... />` or `<path d="M ... Z" />`
  - [ ] Feature styling: apply fill, stroke, stroke-width, and opacity attributes.
  - [ ] Assemble full SVG root `<svg xmlns="http://www.w3.org/2000/svg" viewBox="..."> ... </svg>` as `XML ⊤`.

---

### Milestone 6: Fixture Validation & Natural Earth Vector Data Ingestion
Validate end-to-end functionality against real-world vector fixtures.

- [ ] **6.1 Unit & Fixture Tests (`GeoAgda.Tests.Fixtures`)**
  - [ ] Test Fixture 1: Simple GeoJSON `Point`.
  - [ ] Test Fixture 2: GeoJSON `Polygon` (e.g. single country boundary / bounding box).
  - [ ] Test Fixture 3: `FeatureCollection` with multiple features and properties.
  - [ ] Verify parse $\to$ extract $\to$ render $\to$ serialize pipeline end-to-end.
- [ ] **6.2 Natural Earth Dataset Ingestion**
  - [ ] Benchmark ingestion with low-resolution Natural Earth vector datasets (e.g., `ne_110m_admin_0_countries.geojson`).
  - [ ] Verify complete pipeline rendering into valid SVG output files.
