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
- [x] **Milestone 7: Comprehensive Parsing Left Inverses for JSON, XML, and SVG**
- [x] **Milestone 8: Verified Schema Conformance & Proof-Carrying Extraction Shortcuts**

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

---

### Milestone 7: Comprehensive Parsing Left Inverses for JSON, XML, and SVG via Composition
Construct formal, mechanized left inverse objects (`List Char ↩ XMLDoc` and `List Char ↩ JSONValue` from `Function.Bundles.LeftInverse`) using hierarchical, stage-by-stage composition over $\Sigma$-types and container inductive algebras.

- [ ] **7.1 Theoretical Foundations & Literature Review**
  - [ ] **Literature Grounding:**
    - Rendel & Ostermann (2010), *Invertible Syntax Descriptions: Unifying Parsing and Pretty Printing*.
    - Xie, Schrijvers, & Hu, *Biparsers: Exact Printing for Data Synchronisation* (mechanized in Agda).
    - Danielsson (2010), *Total Parser Combinators*.
    - Abbott, Altenkirch, & Ghani (2005), *Containers: Constructing strictly positive types*.
    - Jansson & Jeuring (1997), *PolyP - a polytypic programming language extension*.
  - [ ] **Mathematical Architectural Insights:**
    - Rather than asserting global round-tripping directly on a recursive monolithic parser, every stage of lexing and parsing forms a local `LeftInverse` (or `Inverse` isomorphism).
    - Composition is carried out categorically: if $A \hookleftarrow B$ and $B \hookleftarrow C$, their composite is $A \hookleftarrow C$ via `Function.Construct.Composition.leftInverse`.
    - Pairs and sequential combinators map over dependent products via `Data.Product.Function.Dependent.Propositional.Σ-↩` or `Data.Product.Function.NonDependent.Propositional.×-↩`.
    - Inductive AST terms $C \star \top$ are inverted by container catamorphism / induction (`Data.Container.FreeMonad.induction`), composing the node-level inversions.

- [ ] **7.2 Primitive & Lexical Left Inverses**
  - [ ] Character & Digit bundles: `Char ↩ Fin 10` and `List Char ↩ ℕ`.
  - [ ] Escaping & String literal bundles: unescaping and delimiter matching as `List Char ↩ String`.
  - [ ] Whitespace handling: canonical token spacing as a retraction pair between raw character streams and token lists `List Char ↩ List Token`.

- [ ] **7.3 Combinators for Left Inverses over Sequences & $\Sigma$-types**
  - [ ] Invertible sequence / list combinator: `(List Char ↩ A) → (List Char ↩ List A)` for delimited and separated elements (commas in JSON, attributes/children in XML).
  - [ ] Invertible $\Sigma$-type combinator: `(A ↩ B) → (∀ {x} → C x ↩ D (to x)) → Σ A C ↩ Σ B D`.
  - [ ] Invertible key-value mapping: `List Char ↩ (String × JSONValue)` and attribute pairs `List Char ↩ (String × String)`.

- [ ] **7.4 Inductive Free Monad Left Inverse for JSON (`List Char ↩ JSONValue`)**
  - [ ] Base cases: null, bool (`trueⱼ`, `falseⱼ`), number, string.
  - [ ] Inductive steps: array elements and object fields via free monad induction over `JSONShape` and `JSONPosition`.
  - [ ] Package into the final closed theorem:
    $$\text{jsonLeftInverse} : \text{List Char} \hookleftarrow \text{JSONValue}$$
    where `to = parseJSONTotal` and `from = printJSON` without premise hypotheses.

- [ ] **7.5 Inductive Free Monad Left Inverse for XML & SVG (`List Char ↩ XMLDoc`)**
  - [ ] Attribute list invertible parsing: `List Char ↩ Attributes`.
  - [ ] Single tag and leaf element inverse: `List Char ↩ (Tag × Attributes)`.
  - [ ] Recursive child element list inversion using container induction over `XMLShape` and `XMLPosition`.
  - [ ] Package into the final closed theorem:
    $$\text{xmlLeftInverse} : \text{List Char} \hookleftarrow \text{XMLDoc}$$
    where `to = parseXMLTotal` and `from = printXML` without premise hypotheses.

- [ ] **7.6 Full Verification & Regression Testing**
  - [ ] Verify both `jsonLeftInverse` and `xmlLeftInverse` with 0 holes, 0 warnings, and 0 errors via the Agda MCP server (`agda_load_and_goals`).
  - [ ] Retain compile-time sanity proofs asserting on the identity retraction on real fixtures in `GeoAgda.Tests.Milestone7`.
  - [ ] Git commit all changes upon milestone completion.

---

### Milestone 8: Verified Schema Conformance & Proof-Carrying Extraction Shortcuts
Leverage constructive evidence of schema conformance to eliminate defensive partiality and enable shortcut projections.

- [x] **8.1 Decidable Schema Conformance Relation (`GeoAgda.Data.JSON.Conformance`)**
  - [x] Define the constructive satisfaction relation `_⊨_ : JSONValue → Schema → Set`:
    - Evidence for `sObject`: proofs that required fields exist and conform to sub-schemas (`FieldEvidence`, `AllFieldsEvidence`).
    - Evidence for `sArray`: pointwise conformity vectors/lists (`All (_⊨ elemS)`).
    - Evidence for primitives: `sNumber`, `sString`, `sExactString`, `sBool`, `sNull`, `sTuple2`.
  - [x] Universe interpretation of schemas: `⟦_⟧ : Schema → Set`.
  - [x] Total decoding from evidence: `decodeFromEvidence : ∀ {v s} → v ⊨ s → ⟦ s ⟧`.
  - [x] Decidability combinators: `decNumber`, `decString`, `decExactString`, `decTuple2`, `decList`, `decField`.
- [x] **8.2 Proof-Carrying Total Extraction ("Extraction by Proof Shortcut")**
  - [x] Define total projection functions parameterized by the conformance certificate in `GeoAgda.Model.GeoJSON.Conformance`:
    - `extractPositionFromEvidence : ∀ {v} → v ⊨ positionSchema → Position`
    - `extractGeometryFromEvidence : ∀ {v} → GeometryEvidence v → Geometry`
    - `extractFeatureFromEvidence : ∀ {v} → FeatureEvidence v → Feature`
    - `extractFeatureCollectionFromEvidence : ∀ {v} → FeatureCollectionEvidence v → FeatureCollection`
  - [x] **Zero Partiality / Total Shortcuts:** Because certificates guarantee at the type level that all required fields, tags, and coordinate arrays exist and conform, total projectors execute without returning `Maybe`, without defensive fallbacks, and without runtime safety guards.
  - [x] Coherence verification at compile time:
    `testExtractionCoherence : validateAndExtract parsedPointFC ≡ extractFeatureCollection parsedPointFC` (`refl`).
- [x] **8.3 Schema Refinements & GeoJSON Domain Schemas**
  - [x] Formal schemas: `positionSchema`, `lineStringSchema`, `polygonSchema`, `pointGeomSchema`, `lineGeomSchema`, `polygonGeomSchema`.
  - [x] Decidable domain checkers: `checkPosition`, `checkGeometry`, `checkFeature`, `checkFeatureCollection`.
  - [x] Wrapper `validateAndExtract : JSONValue → Maybe FeatureCollection` and compile-time test suite (`GeoAgda.Tests.Milestone8`).
