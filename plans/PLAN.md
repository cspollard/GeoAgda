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
- [ ] **Milestone 7: Comprehensive Parsing Left Inverses for JSON, XML, and SVG** (JSON half done: see `plans/JSONPlan.md`; XML/SVG half open)
- [x] **Milestone 8: Verified Schema Conformance & Proof-Carrying Extraction Shortcuts**
- [ ] **Milestone 9: Algebraic Map Representation via Containers & Free Monads (Multi-Source Ingestion to SVG)**

---

## Detailed Milestone Breakdown

### Milestone 1: Container & Free Monad Formulations (JSON & XML/SVG ASTs)
Establish the core algebraic foundation modeling hierarchical document ASTs as free monads over signatures.

- [x] **1.1 Workspace & Library Structure Setup**
  - [x] Configure `GeoAgda.agda-lib` linking `standard-library` and `agda-categories`.
  - [x] Establish `.agents/rules/guidelines.md` for hole-driven development and container conventions.
  - [x] Initialize `src/GeoAgda/` directory structure with base library index `src/GeoAgda.agda`.
- [x] **1.2 JSON Container Definition (`Data.JSON.AST`)**
  - [x] Define `JSONShape` specifying the polynomial functor shapes:
    - Null, Boolean, Number (integral / rational representation), String literals.
    - Array node of length $n$ (`Fin n` positions).
    - Object node with field keys (`Fin n` positions indexed by key labels).
  - [x] Define `JSONPosition : JSONShape → Set` capturing arity and branching for each shape.
  - [x] Assemble `JSONContainer : Container 0ℓ 0ℓ`.
  - [x] Define `JSON : Set → Set` as `JSONContainer ⋆ X` using `Data.Container.FreeMonad`.
  - [x] Specialize `JSON = JSON ⊤` for standard closed JSON terms.
- [x] **1.3 JSON Catamorphisms & Serialization (`Data.JSON.Print`)**
  - [x] Implement `foldJSON` via `Data.Container.FreeMonad.foldr`.
  - [x] Define `printJSON : JSON → List Char` as an algebra over `JSONContainer`.
- [x] **1.4 XML / SVG Container Definition (`Data.XML.AST`)**
  - [x] Define `XMLShape` modeling text nodes, element tags, attributes (`List (String × String)`), and child arity $n$.
  - [x] Define `XMLPosition : XMLShape → Set` indexing child sub-elements.
  - [x] Form `XMLContainer : Container 0ℓ 0ℓ` and `XML = XMLContainer ⋆ X`.
  - [x] Define SVG element constructors (`svg`, `g`, `path`, `circle`, `polygon`, `polyline`, `rect`) as smart constructors over `XML ⊤`.
- [x] **1.5 XML / SVG Pretty Printing (`Data.XML.Print`)**
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
  - [x] Produce `parseJSON : List Char → Maybe JSON`.
- [x] **3.3 Soundness & Left-Inverse Round-Trip Verification**
  - [x] Prove `parseJSON (printJSON v) ≡ just v` for literals and flat structures.
  - [x] Formulate structural induction principle for `JSONContainer ⋆ ⊤` to extend round-trip proofs.


---

### Milestone 4: Schema Validation & Typed GeoJSON Extraction
Bridge untyped JSON free monads to strongly-typed GeoJSON domain models with verified decidable validation.

- [x] **4.1 Lightweight JSON Schema Language (`Data.JSON.Schema`)**
  - [x] Define `Schema` data type (`sNull`, `sBool`, `sNumber`, `sString`, `sArray`, `sObject`).
  - [x] Define validation predicate `_⊨_ : JSON → Schema → Set`.
  - [x] Implement decidable checker `checkSchema : (v : JSON) (s : Schema) → Dec (v ⊨ s)`.
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
  - [x] `Feature`: Geometry + Properties (`List (String × JSON)`) + Optional ID.
  - [x] `FeatureCollection`: `List Feature` + optional bounding box (`BBox`).
- [x] **4.3 Schema-Driven Extractor (`GeoAgda.Model.GeoJSON.Extraction`)**
  - [x] Schemas for GeoJSON objects (`geoJsonSchema`, `geometrySchema`, `featureSchema`).
  - [x] Extraction functions converting validated `JSON` into typed `FeatureCollection`.
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
Construct formal, mechanized left inverse objects (`List Char ↩ XMLDoc` and `List Char ↩ JSON` from `Function.Bundles.LeftInverse`) using hierarchical, stage-by-stage composition over $\Sigma$-types and container inductive algebras.

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
  - [ ] Invertible key-value mapping: `List Char ↩ (String × JSON)` and attribute pairs `List Char ↩ (String × String)`.

- [ ] **7.4 Inductive Free Monad Left Inverse for JSON (`List Char ↩ JSON`)**
  - [ ] Base cases: null, bool (`trueⱼ`, `falseⱼ`), number, string.
  - [ ] Inductive steps: array elements and object fields via free monad induction over `JSONShape` and `JSONPosition`.
  - [ ] Package into the final closed theorem:
    $$\text{jsonLeftInverse} : \text{List Char} \hookleftarrow \text{JSON}$$
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

- [x] **8.1 Decidable Schema Conformance Relation (`Data.JSON.Conformance`)**
  - [x] Define the constructive satisfaction relation `_⊨_ : JSON → Schema → Set`:
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
  - [x] Wrapper `validateAndExtract : JSON → Maybe FeatureCollection` and compile-time test suite (`GeoAgda.Tests.Milestone8`).

---

### Milestone 9: Algebraic Map Representation via Containers & Free Monads (Multi-Source Ingestion to SVG)
Model hierarchical cartographic documents as a strongly-typed polynomial functor and free monad (`MapC ⋆ A`), decoupling spatial topology, graphic primitives, and visual styling from polymorphic domain metadata ($A$). Implement the end-to-end pipeline: multi-source JSON AST ingestion $\to$ thematic combination into `Map A` $\to$ catamorphic translation to `XMLDoc` $\to$ SVG serialization.

- [ ] **9.1 Graphic & Cartographic Primitives Specification**
  - [ ] **Primitive Taxonomy (`MapPrimitive`):**
    - `textP` : Text string, anchor `Position`, orientation angle (degrees), offset $(\Delta x, \Delta y)$ for cartographic labels (countries, mountain ranges, spot height numerals).
    - `markerP` : Point coordinate `Position`, marker symbol geometry (`circle`, `square`, `triangle`, `diamond`, `cross`, `star`).
    - `curveP` : Linear rings and open curve trajectories:
      - `polyline` : Piecewise linear coordinate paths (`List Position`).
      - `bezier` : Smooth cubic / quadratic Bézier curves with control points for hydrographic centerlines and natural elevation contour lines.
    - `areaP` : Closed planar shapes (`List (List Position)`) supporting outer boundary rings and inner enclave/lake holes with `evenodd` fill rules.
  - [ ] **Cartographic Style & Attribute Models (`GeoAgda.Model.Map.Style`):**
    - `FillStyle` : `fillColor : Maybe String`, `fillOpacity : Maybe String`, `fillRule : FillRule` (`nonzero | evenodd`).
    - `StrokeStyle` : `strokeColor : Maybe String`, `strokeWidth : Maybe String`, `strokeOpacity : Maybe String`, `strokeDashArray : Maybe String` (dashed boundaries/tracks), `strokeLineCap : LineCap` (`butt | round | square`), `strokeLineJoin : LineJoin` (`miter | round | bevel`).
    - `TextStyle` : `fontFamily : String`, `fontSize : String`, `fontWeight : FontWeight`, `fontStyle : FontStyle` (`normal | italic` for water features), `textAnchor : TextAnchor` (`start | middle | end`), `dominantBaseline : DominantBaseline` (`central | alphabetic`), `haloColor : Maybe String`, `haloWidth : Maybe String`, `paintOrder : PaintOrder` (`stroke-fill` halo effect).
    - `MarkerStyle` : `radius : String`, `shape : MarkerShape`, `fill : FillStyle`, `stroke : StrokeStyle`.
    - `LayerMeta` : `layerId : String`, `layerClass : String`, `zIndex : ℕ`, `visible : Bool`.
    - `ViewMeta` : `viewBox : ViewBox`, `projection : ProjectionType`, `aspectRatio : String`, `oceanBackdrop : Maybe String`.

- [ ] **9.2 Container & Free Monad Formulation (`GeoAgda.Model.Map.AST`)**
  - [ ] Define the polynomial signature container `MapC = MapShape ▷ MapPosition`:
    ```agda
    data MapShape : Set where
      -- Leaf Graphic Primitives (hold 1 position for the polymorphic payload A)
      textₛ    : String → Position → TextStyle → MapShape
      markerₛ  : Position → MarkerStyle → MapShape
      curveₛ   : CurveGeometry → StrokeStyle → MapShape
      areaₛ    : AreaGeometry → FillStyle → StrokeStyle → MapShape
      -- Branching Structural Nodes (hold Fin n positions for child sub-elements)
      groupₛ   : (groupId : String) (attrs : Attributes) (arity : ℕ) → MapShape
      layerₛ   : (meta : LayerMeta) (arity : ℕ) → MapShape
      mapRootₛ : (view : ViewMeta) (arity : ℕ) → MapShape

    MapPosition : MapShape → Set
    MapPosition (textₛ _ _ _)    = ⊤       -- 1 position: holds payload A
    MapPosition (markerₛ _ _)    = ⊤       -- 1 position: holds payload A
    MapPosition (curveₛ _ _)     = ⊤       -- 1 position: holds payload A
    MapPosition (areaₛ _ _ _)    = ⊤       -- 1 position: holds payload A
    MapPosition (groupₛ _ _ n)   = Fin n   -- n children
    MapPosition (layerₛ _ n)     = Fin n   -- n items in layer
    MapPosition (mapRootₛ _ n)   = Fin n   -- n layers in map
    ```
  - [ ] Define `MapM A = MapC ⋆ A` using `Data.Container.FreeMonad`.
  - [ ] Closed map specialization: `Map A = MapM A`.
  - [ ] Functor instance `mapMap : (A → B) → MapM A → MapM B` via `FM.map`.
  - [ ] Catamorphism engine `foldMapM : (A → B) → (⟦ MapC ⟧ B → B) → MapM A → B` via `FM.foldr`.

- [ ] **9.3 Stage 1: Multi-Source JSON AST Ingestion**
  - [ ] Load and parse heterogeneous inputs (`List Char → Maybe JSONDoc` via `GeoAgda.Parsing.JSON.Parser`):
    - Physical features (bathymetry contours, coastlines, terrain regions).
    - Topography attributes (spot elevations, summits).
    - Cultural features (country polygons, administrative boundary lines).
    - Optional tabular / thematic data (demographics, regional indices).
  - [ ] Schema validation and typed extraction (`GeoAgda.Model.GeoJSON.Conformance`):
    - Verify structural conformance of each document via `checkFeatureCollection`.
    - Extract into strongly-typed `FeatureCollection`s with zero defensive partiality.

- [ ] **9.4 Stage 2: Thematic Combination & `Map A` Construction**
  - [ ] **Spatial & Thematic Combinators (`GeoAgda.Model.Map.Combine`):**
    - `joinByProperty` : Join geometric features with external property records by key / name / ISO code.
    - `assignElevation` : Attribute terrain polygons with hypsometric elevations based on spot heights or geomorphological classes.
    - `filterByBBox` : Spatial clipping and bounding box filtering.
  - [ ] **Layer Stratification & Z-Ordering:**
    - Construct ordered cartographic layers:
      1. `bathymetryLayer : LayerMeta → List (AreaGeometry × Depth) → MapM Depth`
      2. `landBaseLayer : LayerMeta → List (AreaGeometry × Elevation) → MapM Elevation`
      3. `topographyLayer : LayerMeta → List (AreaGeometry × TopoData) → MapM TopoData`
      4. `hydrographyLayer : LayerMeta → List (CurveGeometry × HydroData) → MapM HydroData`
      5. `boundaryLayer : LayerMeta → List (CurveGeometry × AdminData) → MapM AdminData`
      6. `annotationLayer : LayerMeta → List (Position × LabelData) → MapM LabelData`
  - [ ] **Root Map Assembly:**
    - Combine all layers under `mapRootNode : ViewMeta → List (MapM A) → MapM A`.
    - Global bounding box calculation and automatic `ViewBox` derivation.
  - [ ] **Polymorphic Styling Transformations:**
    - Decouple data from rendering via `styleMap : (A → PrimitiveStyle) → MapM A → MapM PrimitiveStyle`.

- [ ] **9.5 Stage 3: Catamorphic SVG Export (Map AST $\to$ XML AST $\to$ Text)**
  - [ ] **Map-to-XML Catamorphism (`GeoAgda.Rendering.SVG.Export`):**
    - Define `mapToXMLAlgebra : ⟦ MapC ⟧ XMLDoc → XMLDoc`:
      - `textₛ` $\mapsto$ `<text x="..." y="..." ...> ... </text>` with halo strokes.
      - `markerₛ` $\mapsto$ `<circle>` / `<path>` marker symbols with projected coordinates.
      - `curveₛ` $\mapsto$ `<path d="M ... L ...">` with `fill="none"` and stroke attributes.
      - `areaₛ` $\mapsto$ `<path d="M ... Z" fill-rule="evenodd">` with fill and stroke attributes.
      - `groupₛ` $\mapsto$ `<g id="..."> ... </g>`.
      - `layerₛ` $\mapsto$ `<g id="..." class="..."> ... </g>`.
      - `mapRootₛ` $\mapsto$ `<svg viewBox="..." width="..." height="..."> ... </svg>`.
    - Evaluate via `exportMapToXML : Projection → MapM PrimitiveStyle → XMLDoc` using `foldMapM`.
  - [ ] **Subsequent Fold over XML AST:**
    - Serialize `XMLDoc` via existing `printSVGDoc` / `foldXMLM` in linear time with verified character escaping.
    - Ensure zero regression on Milestone 7 retraction proofs (`List Char ↩ XMLDoc`).

- [ ] **9.6 Fixture Tests & End-to-End Verification (`GeoAgda.Tests.Milestone9`)**
  - [ ] Compile-time tests validating `foldMapM` correctness on simple map fixtures.
  - [ ] End-to-end integration test reading Natural Earth JSON fixtures, constructing multi-layer `Map A`, and rendering to SVG.
  - [ ] Verify clean rasterization via Inkscape without geometric fill artifacts or escaping issues.

