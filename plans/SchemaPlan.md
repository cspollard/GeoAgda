# SchemaPlan — grow `Data.JSON.Conformance` toward a JSON Schema core

## Status (2026-10-24)

Not started. This is the plan for "option 2" from the design discussion: keep the custom, verified `Schema`
datatype, extend it towards the subset of JSON Schema that real-world schemas (in particular the official GeoJSON
schema) use, and add a decoder so schema *files* can be read by our own pipeline.

## Background

- `Data.JSON.Conformance` defines `Schema` (`sAny`, `sNull`, `sBool`, `sNumber`, `sString`, `sExactString`, `sList`,
  `sTuple2`, `sObjectReq`), the evidence relation `_⊨_` (stated through the `asNull … asObject` projections of
  `Data.JSON.Schema`, not `≡` on `JSON`, because there is no funext under `--safe --cubical-compatible`), a decision
  procedure, a decoded type `⟦ s ⟧`, and `decodeFromEvidence`.
- It is a typed-decoder description, not JSON Schema. It cannot read a `.schema.json`, has no optional fields, no
  unions, no numeric or string constraints, and no `$ref`.
- Conformance is checked **after** the AST is built (`parseJSON` stays schema-free, so `jsonStage` is untouched).
  Decision recorded: do not fuse the schema into the parser.
- Open question from the session: this plan has not yet been checked against the official GeoJSON schema's actual
  constructs. Step 0 does that and fixes the stopping point.

## Goals

1. Cover the official GeoJSON schema (and similar "typical" schemas) with verified checking and decoding.
2. Read schemas from JSON documents via a decoder from `JSON` to `Schema`, rejecting unsupported keywords explicitly.
3. Keep every extension decidable, with evidence that decodes to `⟦ s ⟧`.

Non-goals: full JSON Schema (multiple drafts, `format`, `unevaluatedProperties`, dynamic refs), streaming validation,
fusing validation into the parser.

## Steps

0. **Survey.** List the keywords used by the official GeoJSON schema and a few schemas "in the wild" (the Natural Earth
   fixtures, a typical OpenAPI component). Tabulate keyword → needed / not needed, and set the stopping point.
   Check how `GeoAgda.Model.GeoJSON.Conformance` uses `Schema` today so that the migration cost is known.
1. **Optional fields.** Replace the required-only object schema with fields marked required or optional
   (`sObject : List (String × Bool × Schema) → Schema`). Decoded type: `Maybe A` for optional fields. Decide on
   additional-property behaviour (allow by default, as JSON Schema does) and write it in the module header.
2. **Unions.** `sOneOf`/`sAnyOf` (binary or list). `oneOf` needs "exactly one", so the evidence carries the failure
   of the others; `anyOf` is the simple sum. Decoded type: a sum (`Data.Sum`) or an indexed `Any`.
   Also `type: [..]` as sugar over `sAnyOf`.
3. **Constants and enums.** Generalise `sExactString` to `sConst : JSON → Schema` and `sEnum : List JSON → Schema`,
   which needs decidable equality up to `_≈ⱼ_` from `Data.JSON.Equality`.
4. **Constraints.** `sInteger`, numeric bounds (`minimum`/`maximum`, exclusive variants), `minLength`/`maxLength`,
   `minItems`/`maxItems`, `uniqueItems`. Number bounds depend on a decidable order on `JSONNumber` (mantissa and
   exponent), so first check what `Data.JSON.Number` offers. Skip `pattern` and `format`.
5. **Additional properties and tuples.** `additionalProperties : Schema`, general `prefixItems` (replacing `sTuple2`),
   `items` for the tail.
6. **Recursion (`$ref` / `$defs`).** The hard step. Options, in order of preference:
   a. an indexed definition environment: `Schema Γ` with `sRef : Γ ∋ n`, and `⊨` defined by fuel-free structural
      recursion on the JSON value (the value shrinks at every `$ref` unfolding that goes through an
      array or object), or
   b. fuel as a parameter of the decision procedure, with a lemma that enough fuel exists for any finite value.
   Write the termination argument down before coding; no `TERMINATING` pragmas.
7. **Schema decoder.** `decodeSchema : JSON → Either Error Schema` for the supported subset, so schema files go
   through `parseJSON`. Unsupported keywords give an explicit `Unsupported keyword` error, not silent acceptance.
   Prove a soundness statement of the form: if `decodeSchema j ≡ ok s`, then `s` describes what `j` says for the
   supported keywords (at minimum, a round-trip with a schema printer, in the style of `jsonStage`).
8. **Typed pipeline.** `parseAs : (s : Schema) → List Char → Either Error ⟦ s ⟧` as `parseJSON` followed by decode,
   plus an `encode : ⟦ s ⟧ → JSON` and the theorem `decode s (encode s x) ≈ just x`. Compose with `jsonStage`
   for an indexed `RightInverse` per schema.
9. **Migrate GeoJSON.** Re-express the GeoJSON conformance in the extended `Schema`, load the official schema file
   from `data/fixtures`, and check that both agree on the existing fixtures.

## Rules (from `.agents/rules/guidelines.md`)

- `--safe --cubical-compatible`, no postulates, no termination pragmas, hole-driven proofs via the Agda MCP.
- Stdlib first: check `Data.Sum`, `Data.List.Relation.Unary.{All,Any}`, `Data.Container.*` before writing lemmas.
- One extension per commit, each with a fixture or test in `test/`, conventional commit messages.

## Risks

- `oneOf` evidence (exclusivity) is proof-relevant and can make the decoded type awkward.
- Numeric constraints depend on a decidable order for `JSONNumber`, which may not exist yet.
- `$ref` can force fuel or an indexed environment into every definition, so step 6 may reshape earlier steps.
- Duplicate keys: `lookupField` is first-match while JSON Schema validators differ; document the choice.
