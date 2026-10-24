# JSONPlan — a JSON pipeline where every stage is a proven pseudoinverse of its printer

## Status (2026-10-24)

Phases 0–7 are **done**: `Data.JSON.RoundTrip.jsonStage : RightInverse JSONSetoid Chars` is proved (lexing and parsing
included) with no holes, no postulates and no termination pragmas; the whole library
type-checks, and the executable gives byte-identical SVG to the baseline on all four fixtures (including the 725 KB
Natural Earth file). Done beyond the original phases: `Data.JSON.Conformance` was rebuilt on the container AST
(evidence stated through `asNull … asObject`, not `≡` on `JSON`), `GeoAgda.Model.GeoJSON.Conformance` fixed (its failure
cases had never type-checked against the `with … in` equations; `checkTyped` replaces three copies), the lightweight
`Schema` in `Data.JSON.Schema` (unused) removed, `Invertible.Char` digit tables use `Data.Fin.Patterns`, and tests were
migrated (`Tests/JSONRoundTrip` is new; Milestones 1, 3, 4, 5, 7, 8 load).
Still open: Phase 8 (pretty-printer), `\uXXXX` escapes,
the XML half of Milestone 7 (`GeoAgda.Parsing.XML.Soundness` is a stub), and shrinking `toDigits10`.

## Goal

Every stage of `List Char → JSON` (lexing and parsing included) is paired with a
printing stage, and each pair carries a proof:

```
parse (print x ++ rest) ≡ just (x′ , rest)   with x′ ≈ x      (under a stated "follow" side-condition)
```

Convention: `print` is a section (right inverse) of `parse`; `parse ∘ print ≈ id`.
The converse (`print ∘ parse ≡ id`) is *not* claimed (whitespace, escapes, `1e+0`, etc. are
many-to-one on the parse side).

Stages and their printers:

| Stage | parse | print | follow-condition |
|---|---|---|---|
| digits / ℕ / sign / fraction / exponent | `lexNat`, … | `printNat`, … | next char is not a number-continuation |
| number | `lexNumber` | `printNumber` | `NoLeadingNumCont rest` |
| string literal | `lexString` | `printStringLiteral` (escape) | none (closing quote is self-delimiting) |
| keyword (`null`/`true`/`false`) | `lexKeyword` | `printKeyword` | none |
| token | `lexToken` | `printToken` | inherited from number |
| token stream | `tokenize` | `printTokens` | `ValidTokenSeq` (no two adjacent number tokens) |
| value | `parseValue` | `printTokensOfJSON` | none |
| whole pipeline | `parseJSON` | `printJSON` | none |

## Current state (surveyed 2026-10-23, via the Agda MCP)

- `Data.JSON.AST` loads. It is a container / free-monad encoding (`JSONC ⋆ ⊥`); the old
  inductive constructors (`pure tt`, `null`, `bool`, `number`, `string`, `arrayFromList`) are gone.
- **`GeoAgda.Parsing.JSON.Soundness` does not load** — it still uses the old constructors and
  a few removed names (`isWhitespace`, `primStringToListInv`). This is the main proof file (474 lines);
  its structure (`printTokens`, `ValidTokenSeq`, `correctLexStringChars`) is reusable.
- `Data.JSON.Geo` did not load; it duplicated `GeoAgda.Model.GeoJSON.Extraction` and has since been **deleted**.
- `Data.JSON.Conformance` is 100% commented out, yet `GeoAgda.Model.GeoJSON.Conformance` imports it.
- **`Data.JSON.Print` disagrees with the lexer**: `printPrim primstring = toList` (no quotes, no escaping)
  and object keys are printed unquoted, so `printJSON` output is not valid JSON. Only the token-level printer
  in `Soundness` is right. There must be one printer, not two.
- Layering is inverted: `Data.JSON.Print` imports `GeoAgda.Parsing.Invertible.Number`, which imports
  `Data.JSON.AST`.
- Parsing uses fuel (`parseValue : ℕ → …`), `lexStringChars` is a 20-line nested `with`, and
  `InvertibleParser` has no way to state a follow-condition (so numbers can't use it).
- `Data.JSON.ObjectC` (uniqueness-checked objects via `deduplicate-!`) makes round-trip equality
  unprovable as `≡`: with `--safe --cubical-compatible` there is no funext and `Unique` / `_∈_` are
  proof-relevant.
- Numbers are in good shape: `correctLexNumberSign` already proves the number round-trip with
  `NoLeadingNumCont`; it is just in the wrong place and wrapped in the wrong abstraction.

## Workspace rules this plan follows (`.agents/rules/guidelines.md`)

- Hole-driven: every non-trivial proof via `agda_load_and_goals` → `agda_search_library`/`agda_unify_with_hole` →
  `agda_hole_action`; no `TERMINATING`, no postulates, `--safe --cubical-compatible` everywhere.
- Stdlib first: every stage is a `Function.Bundles.RightInverse` (structure: `IsRightInverse`), per guideline 1.2
  and your instruction — never a raw `parse (print x) ≡ …` statement. `print` is `to`, `parse` is `from` (total with a
  default witness, as `Invertible.Core` does).
- Recursion schemes over ad-hoc matching; **no very long pattern matches** (guideline 6.2) — this is why the
  `lexStringChars` ladder and the 20-clause `validTokenSeq-++` get rewritten.
- Doc comments on every public record/theorem (guideline 3.3).
- Commit at each stable checkpoint with conventional messages (guideline 5). I only stage files I changed: the
  working tree has your staged `Geo.agda` and untracked `test/` + `data/fixtures/...`, which I leave alone.
- Literature (guideline 1.6): the design is the proof-carrying analogue of Rendel & Ostermann, *Invertible Syntax
  Descriptions* (Haskell 2010; partial isomorphisms — [paper](https://www.informatik.uni-marburg.de/%7Erendel/unparse/rendel10invertible.pdf),
  [`partial-isomorphisms`](https://hackage.haskell.org/package/partial-isomorphisms)), with the retraction laws of
  Boomerang-style lenses, and Danielsson's *Total Parser Combinators* (ICFP 2010) as background for termination
  (the last two from memory, not re-checked this session). A web search found no existing Agda development of
  verified JSON biparsers, so nothing to reuse beyond the stdlib.

## Phase 0 results (loaded with the Agda MCP, 2026-10-23)

| Module | Status |
|---|---|
| `Data.JSON.{AST,Print,Schema}`, `GeoAgda.Parsing.JSON.Parser`, `Model.GeoJSON.Extraction`, `Pipeline` | load, no warnings |
| `GeoAgda.Parsing.JSON.Soundness` | **error** (old constructors; missing `isWhitespace`, `primStringToListInv`) |
| `Data.JSON.Geo` | **error** (deleted since) |
| `GeoAgda.Model.GeoJSON.Conformance` | **error** (`Schema` not in scope: `Data.JSON.Conformance` is all comments) |

Pre-existing failures further out (identical at the baseline commit `49662ef`, checked in a throwaway worktree):
`GeoAgda.agda` (hence `Tests/Milestone3`) — `escapeList` defined in both `Data.JSON.Print` and `Data.XML.Print`;
`Tests/Milestone5` — numeric literal where `Fin 10` expected (line 27); `Tests/Milestone7` — via `Soundness`;
`Tests/Milestone8` — via `Model.GeoJSON.Conformance`. `Pipeline`, `Coordinates`, `exe/Main` load fine, and are the
regression guard while migrating. The Phase 7/9 shim removal must fix these, not just preserve them.

Two stdlib facts found while preparing Phase 1 (they change the design, see decisions 1 and 9):
- The stdlib has **no equality on free monads**, only one layer: `Data.Container.Relation.Binary.Pointwise.Pointwise C R`
  / `Data.Container.Relation.Binary.Equality.Setoid`. `_≈ⱼ_` is therefore a small inductive type built on `Pointwise`.
- Under `--safe`, **`toList (fromList cs) ≡ cs` and `fromList (toList s) ≡ s` are not provable** (only injectivity is
  built in; `Data.String.Unsafe` uses `trustMe` and `--with-K`).

## Design decisions (override any of these and I will adapt)

0. **The Container / FreeMonad AST stays** (`JSONC ⋆ ⊥`, `Data.JSON.AST`). Nothing below replaces it; the aim is
   to get as much as possible from the stdlib's container theory instead of hand-rolled proofs.
1. **Equality is `_≈ⱼ_`, not `_≡_`, built on the stdlib.** With `--safe --cubical-compatible` there is no
   funext, so `≡` on container values (which contain position functions) is unprovable. Define `_≈ⱼ_` as the
   inductive free-monad lift of the stdlib's one-layer `Pointwise` (`pure≈`, `impure≈ : Pointwise C _≈ⱼ_ x y → …`);
   prove it an equivalence from `Equality.Setoid`'s `refl/sym/trans`, and prove `printJSON` respects it
   (this is the `to-cong` field of the `RightInverse` bundles). Check `Data.Container.Properties` /
   `Data.Container.FreeMonad` for `map`/`foldr` lemmas before writing any by hand. All top-level theorems are stated
   up to `_≈ⱼ_`.
2. **Object container: simplify, but stay a `Container`.** Preferred: `ObjectC` becomes `List String ▷ (Fin ∘ length)`
   (same shape as `ListC`, no uniqueness in the type; RFC 8259 only says keys *SHOULD* be unique), with `Unique` as
   an optional predicate `WellFormed : JSON → Set`. This removes `deduplicate-!` from the parser and the
   proof-relevant `_∈_` positions that make `_≈ⱼ_` painful. If you want uniqueness kept in the container, `ObjectC`
   stays as is and `_≈ⱼ_` must be proved insensitive to the `Unique` proof (needs Hedberg on `String`).
3. **Stages are stdlib `RightInverse` / `IsRightInverse` bundles, not a custom record.** `print` is `to`, `parse`
   is `from` (total, with a default witness: `nullⱼ`, `0`, `[]`), the round trip is `inverseʳ`. Stages compose with
   `Function.Construct.Composition.rightInverse`; products/sums with `Data.Product.Function.{NonDependent,Dependent}.Setoid`
   / `Data.Sum.Function.Setoid`. `Data.JSON.Stage.mkStage` builds a stage from the partial `Maybe`-parser used at
   runtime. This replaces `InvertibleParser`.
   *Caveat found in Phase 2:* a stage for a **prefix** parser with a follow-condition cannot be a `RightInverse`
   (`from : B → A` would have to produce the `Follow` proof for arbitrary input; making the relation absorb it breaks
   `inverseʳ`). So the prefix round-trip lemmas (`lexToken (printToken t ++ rest) ≡ just (t , rest)` under a
   follow-condition, `parseValue … (printTokens v ++ rest)`) are **internal induction lemmas about the partial
   functions**, not exported contracts. Every *exported* stage — lexeme, token stream, parser, pipeline — is a
   `RightInverse`; lexeme stages are the `rest = []` instances.
4. **Prove on lists, not on `Fin`-lookups — as a view over the container.** `AST` gets a
   `view : JSON → JSONView` / `unview` pair (generalising `matchJSON` from `Geo.agda`) with `view (unview v) ≈ⱼ v`,
   where arrays/objects appear as `List`s (via `listCToList` / `listToListC`). The printer is still the free-monad
   catamorphism `foldJSONM`; the view is only used inside proofs, so the container remains the definition and the
   stdlib fold/`map` lemmas stay usable.
5. **Keep fuel, but only in one place**, with one lemma: `parseValue n (printTokens v ++ rest) ≡ just (v , rest)`
   whenever `n > length (printTokens v)`. (Alternative if this gets ugly: an explicit stack machine, structural
   on the token list. Costlier proofs, no fuel. Fall back to it only if the fuel lemma is a mess.)
6. **Printer is single-sourced:** `printJSON = printTokenList ∘ printTokens` (compact). A pretty-printer is
   added later as a second `RightInverse JSONSetoid Chars` sharing the same `from` (see Phase 8) — no raw equations
   like `tokenize (pretty ts) ≡ tokenize (compact ts)`.
7. **Strings:** escape `"`, `\`, and all control chars (`\n \r \t \b \f`, others as `\u00XX`) when printing;
   lexer accepts the full RFC escape set (incl. `\/`, `\uXXXX`). Parsing more than printing is fine for a
   pseudoinverse. (Stretch: surrogate pairs.)
9. **String payloads are `List Char` in the AST and tokens** (`RetType primstring = List Char`), because the
   `String ↔ List Char` round-trip is not provable under `--safe` (see Phase 0 results). `stringⱼ : String → JSON`
   stays as a boundary convenience (`stringⱼ = stringⱼ′ ∘ toList`); consumers (`Schema.asString`, `Extraction`)
   convert with `fromList`. The `String`-level corollary (`parseJSON (toList (renderJSON v))`) is **not** part of the safe
   core; if wanted it goes in a separate `--with-K` module using `Data.String.Unsafe`.
8. `Data.JSON.Geo` is deleted (it duplicated `GeoAgda.Model.GeoJSON.Extraction`).

## Target layout

```
src/Data/JSON/
  Stage.agda       Chars, Subtype, mkStage (RightInverse from a partial parser)  — done
  Number.agda      JSONNumber, digits, nat/sign/fraction/exponent/number codecs   (from GeoAgda.Parsing.Invertible.Number + AST)
  String.agda      escape / unescape codec for string literals
  AST.agda         JSON container, constructors, JSONView, _≈ⱼ_, view/unview
  Token.agda       JSONToken, printToken, whitespace, keyword + token codecs, tokenizer
  Parser.agda      parseValue (fuel), value codec
  Print.agda       printJSON / renderJSON (single source of truth)
  RoundTrip.agda   jsonStage = parser ∘-rightInverse lexer, plus the partial Maybe parser
  Goals.agda       (temporary) goal signatures with holes — see Phase 1
  Schema.agda      Schema + checkSchema, later with ⊨ evidence (absorbs Conformance)
GeoAgda/Parsing/JSON/*   become thin re-export shims, then deleted
GeoAgda/Parsing/Invertible/{Core,Char,Number}   Core/Char kept for XML until XML migrates
```

Update `test/Everything.agda` (via `make-everything.sh`) after each phase.

## Phases

Every phase ends with `agda_load_and_goals` on the touched modules **and on `test/Everything.agda`** showing no
errors/warnings, and a git commit. Work hole-first; use `agda_search_library` / `agda_get_module_summary`
before inventing lemmas; `agda_get_symbol_implementation` only to learn proof structure.

### Phase 0 — Triage (no behaviour change)
- Load each of `src/Data/JSON/*.agda`, `GeoAgda/Parsing/**`, `Model/GeoJSON/*`, `Tests/*`; record in this file
  what loads and what doesn't (known: `Soundness`, probably `Model.GeoJSON.Conformance`).
- Don't touch the unrelated working-tree files (`data/fixtures/earth_physical_topography.geojson`).
- Delete dead code: commented-out body of `Conformance.agda` (keep its design in Phase 9), unused imports in `AST.agda`
  (`Data.Float`, `Data.Container.FreeMonad` duplicates, …), `Print.print⊤`.

### Phase 1 — Goal file with holes (`src/Data/JSON/Goals.agda`) — **done**
The top-level contract is written with implementations as `?`; it typechecks with 9 open holes
(`_≈ⱼ_`, `JSONSetoid`, `ValidTokenSeq`, four lexeme stages, `lexer`, `parser`). Every stage is a stdlib
`Function.Bundles.RightInverse` (`to` = print, `from` = parse, total with a default witness; `inverseʳ` = the
round-trip law; `.isRightInverse` gives the `IsRightInverse` structure):

```agda
numberStage  : RightInverse (setoid JSONNumber)  Chars     -- also stringStage, keywordStage, tokenStage
lexer        : RightInverse ValidTokens Chars              -- ValidTokens = Subtype (setoid (List JSONToken)) ValidTokenSeq
parser       : RightInverse JSONSetoid ValidTokens         -- to = printTokens (validity is in the type), to-cong = print respects ≈ⱼ
jsonStage    : RightInverse JSONSetoid Chars               -- DONE: Composition.rightInverse parser lexer
```
The headline theorem is already proved *from* `lexer` and `parser` by the stdlib's composition; there is no separate
`_⟫_`, compatibility lemma, or `print-cong` (validity lives in the `ValidTokens` setoid, congruence of printing is
`to-cong`). `renderJSON : JSON → String` stays a one-way convenience (`fromList ∘ printJSON`); the safe theorem is at
`List Char` (decision 9). `Goals.agda` was deleted once every goal had been proved and moved to its home module.

### Phase 2 — Stage infrastructure (`Data.JSON.Stage`) — **done**
- `Chars`, `Subtype` (sub-setoid cut out by a predicate, via `Relation.Binary.Construct.On`), `parseOr`, and
  `mkStage` (a `RightInverse S Chars` from `print`, a partial `parse`, a default, `print-cong`, and the `Maybe`-form
  round trip). Typechecks with no holes.
- Reuse stdlib for everything else: `Function.Construct.{Composition,Identity,Symmetry}`,
  `Function.Properties.RightInverse`, `Data.Product.Function.NonDependent.Setoid._×-rightInverse_`,
  `Data.Sum.Function.Setoid`; look for a `List`-lift of `RightInverse` (else write one, once) when needed for strings.
- `Invertible.Core` (`InvertibleParser`, `unitP`, `mapIso`) stays until XML migrates.

### Phase 3 — Numbers (`Data.JSON.Number`) — **number stage done; digit clean-up pending**
- Done: code moved from `Invertible.Number` (shim left at the old path), `JSONNumber` moved in (re-exported from `AST`,
  so the `AST ↔ Number` cycle is gone), `parseNumber` + `numberStage : RightInverse (setoid JSONNumber) Chars` proved
  with no holes (`mkStage`, `correctLexNumberSign` at `rest = []`).
- Pending: replace `printDigit`/`parseDigit` (10-clause matches in `Invertible.Char`, against guideline 6.2) by stdlib
  `Data.Digit`/`Data.Nat.Show`, and shrink `toDigits10`.
- Move `JSONNumber` here; move digit/nat/sign/fraction/exponent code from `Invertible.Number`. This breaks the
  `AST ↔ Number` cycle: `AST` imports `Number`.
- Keep the existing prefix lemmas (`correctDigitsLoopGen`, `correctLexFraction`, `correctLexExponent`,
  `correctLexNumberSign`) as internal lemmas; `numberStage` is `mkStage` applied to `printNumber` / `lexNumber +/-`
  with `rest = []` (the `NoLeadingNumCont []` side-condition is trivial). The sign (`-` prefix) is dispatched in the stage. Search stdlib first (`Data.Nat.Show`,
  `Data.Digit`, `Data.Nat.DivMod`) to shrink `toDigits10` (≈80 lines of arithmetic; `lem`/`lem′` are suspicious).
- Fix: `lexExponentSign` uses `ℕ.pred (digitsToNat ds)` for negatives — check `e-0` / empty-digit behaviour
  is only relevant on the parse side, and document that.

### Phase 4 — Strings and keywords (`Data.JSON.String`, `Data.JSON.Keyword`) — **done (basic escapes)**
- Done: `Data.JSON.String` (table-driven `escapes`, `lexBody-printBody`, `stringStage`) and `Data.JSON.Keyword`
  (`stripPrefix`, `lexKeyword-print`, `keywordStage`), no holes. Escapes cover `" \\ \n \r \t \b \f` (read back also `\/`).
  Not yet: printing other control characters as `\u00XX` and reading `\uXXXX` (stretch; needs hex digits).
- Table-driven escapes: one `escapeChar : Char → Maybe Char` / `unescapeChar` pair with
  `unescape (escape c) ≡ c` as a lemma, replacing the nested `with` ladder in `lexStringChars`
  and the `∈ escapeList` check in `Print`. Per-character escaping is a `RightInverse` of chars to char-lists; the
  string stage is the `List`-lift of it (look for a stdlib list/`map` lifting of `RightInverse` first,
  e.g. in `Data.List.Relation.Binary.Pointwise` / `Function.Properties.RightInverse`).
- `stringStage : RightInverse (setoid (List Char)) Chars` (quoted literal) via `mkStage`, from the prefix lemma.
- `keywordStage` for `null`/`true`/`false` (replaces three literal clauses in `lexToken`).

### Phase 5 — AST cleanup (`Data.JSON.AST`) — **done**
- Done: `ObjectC` is now `List Key ▷ (Fin ∘ length)` (`Key = List Char`, duplicates allowed, `Data.JSON.ObjectC` deleted);
  string payloads and keys are `List Char` (`stringⱼ`/`objectFromList` still take `String`, `stringⱼ′`/`objectFromList′`
  take `List Char`); array/object converters are `foldr`-based; dead code (`JSONType≟` etc., unused imports) removed;
  `Schema.asString/asObject` convert with `fromList`; `Data.JSON.Print` is rewritten as a compact `foldJSONM`
  catamorphism over the shared `printNumber`/`printStringLiteral`/`keywordText` (the old unquoted printer is gone).
- Done: `Data.JSON.Equality`: `_≈ⱼ_` (one constructor per node kind, shape equations on `ℕ` / `List Key` instead of the
  dependent shape pair — this avoids Σ-injectivity under `--cubical-compatible`; it is *not* stdlib `Pointwise`, which
  would force that extraction), `≈ⱼ-refl/sym/trans`, `JSONSetoid`, and the two structural lemmas the parser proof
  needs: `arrayⱼ-go` and `objectFromList′-go` (a list pointwise-bisimilar to a node's children rebuilds a bisimilar
  node). No `JSONView` was needed.
- Keep the container/free-monad definition. Apply decisions 1, 2, 4: simplify `ObjectC` to a `List String`-shaped
  container (still a `Container`), add `JSONView`/`view`/`unview`, and define `_≈ⱼ_` from the stdlib container
  equality (prove it is an equivalence by instantiating the stdlib setoid, not by hand). Smart constructors `nullⱼ … objectⱼ` kept with the same names (callers in
  `Schema`, `Extraction` keep working); `objectFromList` becomes total without dedup.
- Collapse `JSONType≟`/`PrimJSONType≟` (16-clause) if unused; otherwise derive via a code/decode map.
- Update `Schema.agda`'s `asObject`, `lookupField` for the new object shape; keep `lookupField` first-match semantics.

### Phase 6 — Tokens, lexer, parser — **done**
- Done: `Data.JSON.Token` (`JSONToken`, `printToken`, `lexToken` dispatching on `parseDigit` first,
  `lexToken-printToken` under `TokenFollow`, `tokenStage`) and `Data.JSON.Lexer` (`skipWS`, fuel-based `tokenize`,
  `ValidTokenSeq = Linked NotAdjacent` from the stdlib, `tokenize-print`, and
  `lexer : RightInverse ValidTokens Chars` — `from` checks the decidable validity and falls back to `[]`).
  No holes. The "segmentation layer" alternative was *not* needed: `from` into a `Subtype` with a decidable
  predicate is enough, and the prefix lemma stays internal as planned.
- Done: `Data.JSON.Tokens` (`printTokens` as a `foldJSONM`, `printTokens-valid` via `Linked.++⁺`,
  `printTokens-head`, `printTokens-cong`) and `Data.JSON.Parser` (`parseValue` with the fuel invariant
  "fuel ≥ tokens consumed", `arrayLoop-print`/`objectLoop-print`, `parseValue-print`, and
  `parser : RightInverse JSONSetoid ValidTokens`). The case split on the first token uses a small datatype
  `ValueStart` instead of a 11-way match. No holes anywhere.
- `Token.agda`: `JSONToken`, `printToken`, `printTokens` (moved from `Soundness`), `tokenStage`, whitespace `skipWS`
  (a token never prints with leading whitespace: this is part of `TokenFollow`). `lexer : RightInverse ValidTokens Chars`
  is the iteration of `tokenStage` over the input (`ValidTokenSeq` is exactly what makes the follow-conditions line
  up); fuel only inside the proof. Reuse `validTokenSeq-++` from `Soundness` (collapse its 20 clauses with a helper).
- `Parser.agda`: `parseValue` stays fuel-based; prove the fuel lemma of decision 5 and
  `parser : RightInverse JSONSetoid ValidTokens`, mutual with `parseArrayElements`/`parseObjectEntries`. `to` is
  `printTokens` paired with its validity proof (the compatibility lemma is *in the type*); `to-cong` is
  "printing respects `_≈ⱼ_`".

### Phase 7 — Printer and top-level theorem — **done**
- Done: `Data.JSON.Print.printJSON = printTokenList ∘ printTokens`; `Data.JSON.RoundTrip.jsonStage =
  Composition.rightInverse parser lexer` (the headline `RightInverse JSONSetoid Chars`), `to-printJSON`, the partial
  `parseJSON` and `parseJSON-printJSON`. `GeoAgda.Parsing.JSON.{Parser,Lexer}` are shims; `Soundness` is deleted and
  `Goals.agda` is gone (no goals left).
- Original plan text, kept for reference:
- `Print.agda`: `printJSON := to jsonStage` (= `printTokenList ∘ printTokens`); `renderJSON := fromList ∘ printJSON`;
  delete the old printer.
- `RoundTrip.agda`: `jsonStage = parser ∘-rightInverse lexer` (`Function.Construct.Composition.rightInverse`) — the
  headline theorem, as a stdlib `RightInverse` bundle (with `IsRightInverse` structure via `.isRightInverse`);
  parse is `from` with default witness `nullⱼ`, the partial `Maybe` parser is exported alongside with a lemma
  that `from = parseOr nullⱼ`. No `String`-level statement (decision 9).
- Retire `GeoAgda.Parsing.JSON.{Lexer,Parser,Soundness}`: keep re-export shims for one phase for
  `Pipeline`, `Tests/*`, then remove.

### Phase 8 — Pretty-printer (optional but desirable)
- A `Layout`-parameterised printer, again as a stdlib `RightInverse JSONSetoid Chars` whose `from` is the *same*
  `parseJSON`. Layout-insensitivity is then not a raw equation: it is the fact that one parser is a right-inverse
  witness for both the compact and the pretty printer (`Function.Properties.RightInverse` gives that the two `to`s
  are related through `from`). This is the version `renderJSON` for the CLI should use.

### Phase 9 — Schema and clean-up
- `Schema.agda`: single schema language; add the `_⊨_` evidence relation (from the commented `Conformance.agda`)
  and `checkSchema ≡ true ⇔ ∃ evidence` soundness; delete `Conformance.agda`; repoint
  `GeoAgda.Model.GeoJSON.Conformance`.
- Remove `Goals.agda`, refresh `PLAN.md` Milestone 7 (items 7.1–7.4 are now this plan), regenerate `Everything.agda`.

## Verification

1. `agda_load_and_goals` on each module after each phase: `open_holes`, `warnings`, `errors` all empty
   (Phase 1 is the only phase allowed to end with holes; the Goal file must still typecheck modulo holes).
2. `agda_load_and_goals test/Everything.agda` — the whole library, `--safe`, no postulates/`TERMINATING`
   (`grep -rn "postulate\|TERMINATING\|trustMe\|primTrustMe" src` must be empty).
3. Headline check in a scratch module: `jsonStage`'s type is exactly `RightInverse JSONSetoid Chars` as in Phase 1 (use `INFER_TYPE`).
4. Concrete regression: run the executable (`make`) over `data/fixtures/earth_physical_topography.geojson`
   — `parseJSON` succeeds, `parseJSON (renderJSON j)` succeeds and matches, and the SVG output is unchanged
   (compare to `test_out.svg`).
5. `Tests/Milestone{3,5,7,8}` still compile after the shims are removed.

## Risks

- **Fuel lemma / mutual induction** in the parser proof is the hardest piece; fallback is the stack-machine parser.
- **No funext** pushes everything through `_≈ⱼ_`; downstream code (`Schema`, `Extraction`) must never need `≡` on `JSON`.
  I believe it doesn't (it only inspects), but Phase 5 will confirm.
- Schema/GeoJSON modules outside `Data/JSON` depend on removed names; handled by shims, then migrated in Phase 9.

## Resolved questions

- **Object keys:** follow the spec. RFC 8259 §4 says names within an object "SHOULD be unique" (not MUST), so the
  parser must accept duplicates and the printer must preserve them. Decision 2 is therefore final: `ObjectC` becomes a
  non-unique, list-shaped `Container`; `WellFormed` (unique keys) is an optional predicate, not part of the type.
  `lookupField` keeps first-match semantics.
- **`Data.JSON.Geo`** is deleted (decision 8, revised 2026-10-24).
