# GeoAgda Workspace Guidelines & Coding Standards

This document establishes the architecture principles, design patterns, coding standards, and agent workflows for **GeoAgda**—a verified Agda library for parsing, manipulating, and rendering geospatial map data, starting with GeoJSON vector data from Natural Earth.

---

## 1. Core Architectural & Design Principles

### 1.1 Container & Free Monad AST Representations
- **Trees as Container Algebras:** ASTs representing hierarchical data formats (JSON, XML/SVG) must be defined as free monads over well-specified containers (`Data.Container.Core`, `Data.Container.FreeMonad`).
- **Signature Containers:** Define explicit `Shape` and `Position` types characterizing node constructors and child arities:
  - For JSON: `JSONShape` describes literals, arrays, and object key-value sequences, while `JSONPosition` indexes branching to child nodes or subterms.
  - For XML/SVG: `XMLShape` models element tags, attributes, and text nodes, while `XMLPosition` indexes child subtrees.
- **Leaf Polymorphism:** Free monads `C ⋆ X` preserve parameterization over variable/leaf representations `X`, enabling semantic annotations, error tokens, or terminal unit values (`⊤`).

### 1.2 Invertible & Verified Parsing
- **Formal Left Inverses:** Parsing is treated not merely as a partial function, but formally as an explicit left inverse (`Function.LeftInverse.LeftInverse` from `agda-stdlib`) between concrete string encodings (`List Char` or `String`) and abstract syntax (`C ⋆ X`).
- **Round-Trip Soundness:** Every parser `parse` accompanied by a pretty-printer `print` satisfies the inversion property:
  $$\forall a \implies \text{parse} (\text{print } a) \equiv \text{just } a$$
- **Compositional Construction:** Parsers and formatters must be assembled by composing smaller isomorphisms, bijections (`Function.Bijection`), and left inverses:
  - Digit and numeric conversions (`Char ↔ Fin 10`, `List (Fin 10) ↔ Nat`, floating/rational coordinates).
  - Lexical tokenizers and whitespace combinators.
  - Recursive AST combinators preserving left-inverse properties.

### 1.3 Recursion Schemes & Combinators
- **Algebraic Catamorphisms:** Avoid ad-hoc structural pattern matching for tree transformations. Use standard catamorphisms and recursion schemes provided by the container library:
  - `foldr` and `induction` from `Data.Container.FreeMonad`.
  - Functorial mapping (`_<$>_`) and monadic sequencing (`_>>=_`).
  - Container predicate extensions (`Data.Container.Relation.Unary.All.□`, `Data.Container.Relation.Unary.Any.◇`).
- **Category-Theoretic Abstractions:** Leverage `agda-categories` for functors, natural transformations, monads, and algebraic gadgets when mapping across AST representations.

### 1.4 Strict Hole-Driven Development
- **No Synthetic or Hallucinated Code:** Never emit unverified proofs, non-trivial lemmas, or speculative pattern matching.
- **MCP Verification Loop:**
  1. Insert typed holes (`?` or `{!!}`) for unproven terms or open goals.
  2. Invoke `agda_load_and_goals` via the Agda MCP to extract normalized goal types and local contexts.
  3. Query candidates using `agda_search_library` and `agda_unify_with_hole`.
  4. Refine or fill goals using `agda_hole_action` (`GIVE`, `REFINE`, `CASE_SPLIT`).
  5. Verify successful typechecking of the final source.

### 1.5 Standard Library & Categories First
- **Search Before Authoring:** Before introducing custom types, helper predicates, or arithmetic/relational lemmas, thoroughly search `agda-stdlib` and `agda-categories`.
- **Reuse Standard Concepts:** Rely on standard equality (`Relation.Binary.PropositionalEquality`), decidability (`Relation.Nullary.Decidable`), products/sums (`Data.Product`, `Data.Sum`), lists/vectors (`Data.List`, `Data.Vec`), and function constructions (`Function.*`).

### 1.6 Literature Review & Mathematical Grounding
- **Always Check Literature Before Writing Code:** Before implementing non-trivial algorithms, verified parsers, domain models, or categorical structures, agents must search and review relevant computer science and mathematical literature (e.g., papers on invertible syntax descriptions, biparsers, type-directed parsing, semantic subtyping, container algebras, and constructive geometry).
- **Leverage Established Foundations:** Utilize existing theoretical insights, formalization techniques, and published best practices rather than designing ad-hoc or unverified formulations from scratch. Ground definitions in proven mathematical paradigms (e.g., Martin-Löf universes for schemas, retraction pairs for parsing, free monads over polynomial functors for ASTs).

---

## 2. Directory Structure & Module Layout

The library is organized under `src/GeoAgda/`:

```
GeoAgda/
├── Container/                 -- General container extensions and recursion schemes
│   ├── Indexed.agda           -- Indexed containers and polynomial functors
│   └── Combinators.agda       -- Custom container combinators and folds
├── Data/
│   ├── JSON/
│   │   ├── AST.agda           -- JSON Container, Free Monad (JSONShape, JSONPosition, JSON)
│   │   ├── Print.agda         -- JSON pretty-printing catamorphisms
│   │   ├── Schema.agda        -- Typed JSON schemas and validation predicates
│   │   └── Dec.agda           -- Decidable schema checking procedures
│   └── XML/
│       ├── AST.agda           -- XML/SVG Container and Free Monad
│       └── Print.agda         -- XML/SVG serialization
├── Parsing/
│   ├── Invertible/
│   │   ├── Core.agda          -- Invertible parsing primitives & LeftInverse combinators
│   │   ├── Char.agda          -- Character, digit, and whitespace left inverses
│   │   └── Number.agda        -- Natural, integer, and float/rational parsers
│   └── JSON/
│       ├── Lexer.agda         -- Invertible lexical tokenization
│       └── Parser.agda        -- Invertible JSON parser with LeftInverse proofs
├── Model/
│   └── GeoJSON/
│       ├── Types.agda         -- Position, Geometry, Feature, FeatureCollection
│       ├── Extraction.agda    -- Schema-driven extraction from JSON Free Monad to GeoJSON
│       └── Properties.agda    -- Extraction correctness and well-formedness proofs
└── Rendering/
    └── SVG/
        ├── Coordinates.agda   -- Projection from geographic coords (lon/lat) to screen space (x/y)
        ├── Styling.agda       -- Stroke, fill, opacity, and CSS presentation attributes
        └── Render.agda        -- Catamorphism mapping GeoJSON models to SVG Free Monads
```

---

## 3. Agda Coding Conventions & Style

### 3.1 Safety and Compiler Flags
- Top-level library modules must enable safe mode whenever possible:
  ```agda
  {-# OPTIONS --safe --cubical-compatible #-}
  ```
- All definitions must pass Agda's termination checker without pragmas such as `{-# TERMINATING #-}` or `{-# NO_TERMINATION_CHECK #-}`.

### 3.2 Unicode & Idiomatic Symbols
GeoAgda embraces idiomatic Agda notation:
- Container free monad: `_⋆_`, `pure`, `impure`, `⟦_⟧`
- Function composition & inverses: `_∘_`, `LeftInverse`, `_↔_`, `_≅_`
- Logic & types: `∀`, `∃`, `Σ`, `×`, `⊎`, `⊤`, `⊥`, `≡`, `≢`
- Levels: `0ℓ`, `Level`, `_⊔_`, `suc`

### 3.3 Documentation & Specifications
- Every public record, data type, and primary theorem must include doc comments specifying:
  - Mathematical / category-theoretic meaning.
  - Round-trip and soundness guarantees.
  - Standard library modules from which base components are derived.

---

## 4. Testing & Verification Strategy

1. **Self-Contained Fixtures:** Minimal test fixtures (e.g., GeoJSON `Point`, `LineString`, `Polygon`, and small `FeatureCollection`) must be defined as both raw string constants and typed Agda records.
2. **Round-Trip Proofs:** Key parsers must prove left-inverse properties for all well-formed fixtures:
   `parse (print fixture) ≡ just fixture`
3. **Continuous Verification:** The entire codebase must be verified via Agda typechecking (`agda GeoAgda.agda-lib src/...`) on every change.

---

## 5. Version Control & Checkpoint Commits

1. **Commit at Stable Checkpoints:** Upon reaching any stable checkpoint (e.g. completing a milestone subtask, verifying a new module without errors or unproven obligations, or landing an invertible parsing/rendering component), all related code, tests, and documentation must be committed to the git repository.
2. **Descriptive Commit Messages:** Commits should follow conventional, structured messages summarizing the verified progress (e.g., `feat(json): define JSON container and free monad AST`).
3. **Clean Working Tree:** Unnecessary artifacts (such as `.agdai` interface files) must be excluded via `.gitignore`.


## 6. Style

1. Use standard induction/recursion functions wherever possible (foldr, foldl,
   etc.)
2. Avoid very long pattern matches; use stdlib-defined patterns (e.g.
   Data.Fin.Patterns) or induction.
