# XMLPlan — an XML/SVG pipeline in the style of the JSON one

## Status (2026-10-24)

Phases 1–5 done (2026-10-24), so the AST is in its target state and awaits review; Phases 6–8 (printer proofs, parser, theorem) are next. The JSON pipeline (`plans/JSONPlan.md`) is complete: `jsonStage` is a proven right inverse of the
printer over a container AST. This plan brings `Data.XML` to the same shape. **Scope of the first pass: the AST
only** (Phases 1–5). The parser/printer and the right-inverse theorem (Phases 6–8) are outlined, and are to be
detailed once the AST has settled.

## Goal

`parseXML : List Char → Maybe XML` and `printXML : XMLDoc → List Char` with `parseXML (printXML x) ≈ₓ just x`,
where `≈ₓ` is a bisimilarity on the free-monad AST (no funext under `--safe --cubical-compatible`), assembled from
stages as in `Data.JSON.Stage`.

## Review findings (from the AST audit)

Compared with `Data.JSON.AST`, `Data.XML.AST` has:

1. **`String` payloads** (tags, attribute keys and values, text). The `String ↔ List Char` round trip is not provable
   under `--safe`, so no right-inverse theorem is possible. This is the one blocker.
2. **A duplicated list container** (`ListC`, `foldListC`, `listCToList`, `listToListC` are copied from `JSONCont`).
3. **A hand-rolled signature** (`XMLShape` / `XMLPosition` by pattern matching) rather than stdlib container
   combinators.
4. **Redundant aliases** (`XMLContainer = XMLC`, `XML = XMLM`).
5. **SVG vocabulary in the XML module** (`svg`, `g`, `path`, `circle`, `rect`, `polygon`, `polyline`).
6. **No module header**, and unused imports (`lsuc`, `Bool`, `⊤`, `tt`, `lookup`, `CC`).
7. **No `Equality` module** (bisimilarity), which the theorem statement needs.
8. **Two printers** (`printXML`, `printSVGDoc`) with different escaping; `printXML`'s backslash scheme is not XML.
9. **An old fuel-based parser** (`Parsing/XML/Parser.agda`, with a ~10-way `with` chain in `lexName`) and a stub
   `Soundness.agda`.

## Design decisions (settled 2026-10-24 unless marked)

- **Payloads are `List Char`**, via `Name = List Char` and `Text = List Char`. Primed constructors take characters
  (`text′`, `elementList′`); unprimed ones take `String` and apply `toList`, as `stringⱼ` / `stringⱼ′` do.
- **The AST rules out ill-formed XML** (no separate normal-form hypothesis in the theorem). Mechanisms:
  - **Adjacent text nodes / bare text nodes** are unrepresentable by using XML's mixed-content shape: an element with
    `n` element children carries `n + 1` text slots, `t₀ e₁ t₁ … eₙ tₙ`, where an empty slot means "no text".
    Each content has exactly one representation and there is no separate text node, so the container has a single
    kind of node and no `⊎` or tag type is needed (this settles the "tagged type vs `CC.⊎`" question).
    ```agda
    ElementC = CC.Σ (Name × Attributes × Σ ℕ (Vec Text ∘ suc)) (λ (_ , n , _) → Fin n)   -- shape; positions
    XMLC     = ElementC            -- XMLM A = XMLC ⋆ A, XMLDoc = XMLM ⊥
    ```
    (exact packaging to be settled in the Phase 3 spike; a record shape is fine if it folds more cleanly).
  - **Valid names** (tag and attribute names): the shape carries a proof of a decidable predicate `ValidName`,
    stored as `True (validName? cs)`, which is `⊤` or `⊥` and so definitionally proof-irrelevant without K.
  - **Valid characters** in text and attribute values: the full XML 1.0 `Char` production
    (`U+9`, `U+A`, `U+D`, `U+20–D7FF`, `U+E000–FFFD`, `U+10000–10FFFF`), as a decidable range test on `toℕ c`,
    stored as `True (validChar? c)` per character. Non-ASCII text passes through the escaper unchanged. The
    escaper touches only `& < > "` and `\r` (printed `&#13;` to survive line-end normalisation), and a lemma shows
    its output characters are valid. Other Agda `Char`s (e.g. `U+0`) are unrepresentable, and the parser rejects them.
  - **Unique attribute names**: a `Unique` proof in the shape. This one is not definitionally irrelevant, so `≈ₓ`
    compares the underlying data and ignores proofs (it is a custom relation anyway).
  - **Single root** is automatic: a document is one element, `XMLM ⊥`.
  - **Names** use an ASCII grammar (`[A-Za-z_:][A-Za-z0-9_:.-]*`), which covers SVG. `ValidName` is isolated in
    `Data.XML.Valid` behind `validNameStart?` / `validNameChar?`, so widening to the full Unicode `NameStartChar`
    intervals later changes only those two predicates and their lemmas, not the AST interface.
- **Attribute order is preserved** (`List`), as with JSON object keys.
- **Canonical printer is the entity-escaped one** (`&amp; &lt; &gt; &quot;`, plus `&#13;`), since SVG output must be
  valid XML. The backslash printer is deleted, not kept as a second path. Subset to parse back: elements,
  attributes, text, self-closing tags. Declarations, comments, CDATA, processing instructions and
  namespaces-as-structure are non-goals.
- **Whitespace**: text is preserved verbatim; the printer emits no indentation, so the round trip is exact. A
  pretty-printer, if wanted, is a later optional phase (as JSON Phase 8).
- **`XMLDoc = XMLM ⊥`** with the same "not `∀ {A}`" comment as `JSON`. `XMLM` is kept for the free-monad form.
- **Shared list container** lives in `Data.Container.List`.

## Target layout

```
src/Data/Container/List.agda        -- shared ListC + folds
src/Data/XML/Valid.agda             -- ValidName, valid-character and Unique predicates (decidable)
src/Data/XML/AST.agda               -- container, free monad, constructors, folds (XML only)
src/Data/XML/Equality.agda          -- _≈ₓ_ bisimilarity, equivalence proofs
src/Data/XML/Escape.agda            -- entity escaping stage (RightInverse), analogous to Data.JSON.String
src/Data/XML/Token.agda  Lexer.agda -- tag/attribute/text tokens and lexer stage
src/Data/XML/Parser.agda            -- token list ↔ AST stage
src/Data/XML/Print.agda             -- single printer
src/Data/XML/Stage.agda             -- xmlStage: composite RightInverse (or reuse Data.JSON.Stage)
src/Data/SVG.agda                   -- svg, g, path, circle, rect, polygon, polyline
```

## Phases

### Phase 1 — Baseline — **done**
Typecheck everything (`make check`) and record that the tree is green. Commit nothing yet. Check whether
`Data.JSON.Stage` is generic enough to host the XML stages; if not, note what has to be generalised.

### Phase 2 — Shared list container — **done**
Move `ListC`, `foldListC`, `listCToList`, `listToListC` into one module and have `Data.JSON.AST` and `Data.XML.AST`
import it. Any lemmas the JSON proofs use about them move too. JSON must still typecheck unchanged apart from imports
(`agda_check_modules` on `Data.JSON.*`, `GeoAgda.Model.GeoJSON.*`).

### Phase 3 — Recast `Data.XML.AST` — **done**

Outcome, where it differs from the text below: the shape is a **record** (`XMLShape`) with `Vec Text (suc arity)` and
three `T (… )` proofs; validity is `Bool`-valued (`isValidName`, `isValidAttrs`, `isValidTexts`, …), so the
evidence is definitionally irrelevant. Raw constructors are `node`, `leaf`, `parent`, `parentList`. Runtime data goes
through `Data.XML.Sanitize` (`element`, `textElement`, and primed `List Char` versions), which repairs invalid input
(U+FFFD, `_`, last duplicate attribute wins) and proves the result valid. There is now a single printer
(`Data.XML.Print`, entity-escaped, self-closing empty elements). The old `GeoAgda.Parsing.XML.{Parser,Soundness}`
modules and the XML round-trip tests in `Milestone7` were **removed** rather than ported (the old parser read the
backslash syntax and text nodes); `Milestone7` now has printer tests. They return in Phase 7/8.
Start with `Data.XML.Valid` (predicates with `Dec`, small fixtures). Then, in the JSON header style: `List Char`
payloads, the mixed-content element container with validity proofs in the shape, remove `XMLContainer` / `XML`, prune
imports, keep `elementC` and `leafElement` only if used. Smart constructors take the proofs by instance or
`True`-style implicit arguments so literals like `elementList "g" [] []` stay readable (`String` wrappers decide
validity by computation). Spike the container packaging first (record shape vs nested `Σ`) by writing `foldXMLC`. Update `Print`, `Parser`, `Render` and the tests for the
payload change. Commit when everything typechecks.

### Phase 4 — Move SVG constructors — **done**
Create `Data.SVG` with the SVG constructors (they take `String` for convenience). Update `Render.agda` and
`Milestone7`. `GeoAgda.agda` re-exports both modules.

### Phase 5 — `Data.XML.Equality` — **done**
`_≈ₓ_` with a single `≈element` (equal tag, attributes and text slots, arity equality `e : n ≡ m`, children related
through `subst Fin e`; validity proofs ignored), mirroring `_≈ⱼ_`. Prove refl, sym, trans, and the `Setoid`. Optionally, show it
agrees with the stdlib `Data.Container.Relation.Binary.Pointwise` on one layer.

**Stop here for review.** The AST is then in the target state.

### Phase 6 — Printer and escaping (outline)
One printer, defined by `foldXMLM`. An `Escape` stage with a right inverse: `unescape (escape cs) ≡ just cs`, where
the unescaper handles the five predefined entities and rejects the rest. Name and attribute-value variants as in
`Data.JSON.Keyword`.

### Phase 7 — Tokens, lexer, parser (outline)
Tokens: open (name, attributes, self-closing flag), close name, text. `lexer` is a right inverse of the token
printer. The parser builds the tree from tokens by structural recursion on a well-matched token stream; the matching
tags are checked, not assumed. Prefer the same `RightInverse` plumbing as `Data.JSON.Parser`, and avoid fuel (no
`TERMINATING`). Remove the old `Parsing/XML/*` modules once replaced.

### Phase 8 — Top-level theorem (outline)
`xmlStage`, and `parseXML (printXML x) ≈ₓ just x` composed from the stages. Add fixtures in `GeoAgda.Tests`
(`parse (print fixture)`), including SVG output from `Render`.

## Verification

`make check` only covers `Main`; use `bash make-everything.sh` to check every module (green as of Phase 5, after
`Data.JSON.Geo` was removed).

- `make check` after every phase; the `Data.JSON.*` and GeoJSON modules must stay green in Phases 2 and 3.
- Hole-driven development via the Agda MCP for all proofs (guidelines §1.4).
- No postulates, no termination pragmas; `--safe --cubical-compatible` on every module.

## Risks

- **Proofs in the shape.** `Unique` proofs are not definitionally irrelevant, so any equality on shapes must go
  through the underlying data. Mitigation: `≈ₓ` is custom and ignores proofs; the parser's right-inverse theorem is
  stated up to `≈ₓ` anyway.
- **Parser must produce the proofs.** The parser decides `ValidName` etc. and fails otherwise, so `parseXML` returns
  `Maybe XMLDoc` with real rejections, and the printer-side theorem supplies the proofs from the AST. Keep the
  predicates simple and computable to avoid dragging decision lemmas into every stage.
- **Mixed-content slots make the parser stateful**: it has to fold adjacent text tokens into one slot. Tokenising
  adjacent text as a single token (lexer maximal munch) keeps the stage a clean right inverse.
- **Smart-constructor ergonomics** for `Render.agda` (many literal elements with `String` args). If implicit proofs are
  noisy, add `String`-taking wrappers that decide validity and are `⊥`-free on literals.
- **Printer change alters SVG output.** `renderSVG` already uses the entity escaper, so `Milestone5` outputs should
  not change, except that text slots now sit between children. Confirm by diffing the fixtures.
- **Existing SVG that renders invalid names or characters** (e.g. an attribute name like `fill-rule`) must pass
  `ValidName`: `-` is allowed in the grammar above, but check every name `Render.agda` emits.

## Open questions

None outstanding. Decisions recorded above: ASCII names now (widenable), full XML 1.0 characters in text and values.
