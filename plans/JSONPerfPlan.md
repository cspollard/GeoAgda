# Plan: faster JSON parsing and checking

Status: **Phases 1–2 done (2026-10-25).** Phase 3 optional. Library changes are on branch `perf/fast-char-eq`
of the `parsnip` submodule (not pushed).

## Baseline
Measured with `exe/Profile.agda` (see `plans/SVGPerfPlan.md`), on `earth_physical_topography.geojson` (2.4 MB):

| stage | before | after |
|---|---|---|
| tokenize | 0.34 s mutator, 4.0 GB allocated | 0.12 s, 0.74 GB |
| parse (tokens → JSON) | +0.03 s | +0.03 s |
| whole pipeline (`svg`) | 1.5 s mutator, 15 GB allocated | 0.64 s, 4.6 GB |

Type-checking is not a problem: the whole `parsnip` library checks cold in ~16 s (about half of it loading the
stdlib interfaces), the app in ~8 s; no module takes more than 2 s (`agda --profile=modules`).
The proof-heavy modules are `Data.JSON.Number`, `Data.JSON.Parser`, `Data.XML.Parser`.

## Phase 1 — profile (done)
GHC profiling of the generated Haskell works at `-O0`
(`agda --compile --ghc-flag=-prof --ghc-flag=-fprof-auto --ghc-flag=-O0`; `-O1` hits a GHC panic).
The tokenizer's top cost centres were `Relation.Nullary.Decidable.Core.map′`, `primCharToNat`, `does`,
`Data.Nat.Properties._≟_`, `_⊎-dec_`, `Any.any?`: i.e. the stdlib's `Dec`-combinator character equality
(`Data.Char.Properties._≟_`) and list membership (`_∈?_`, used by `skipWS`), ~70% of time and allocation.

## Phase 2 — fix (done)
- New `Data.Char.Fast` in `parsnip`: `_≟_ : (c d : Char) → Dec (c ≡ d)` (compares code points with the primitive
  `_≡ᵇ_`) and a directly recursive `_∈?_`. Same types as the stdlib versions, so it is a drop-in import swap in
  `Data.Invertible.Char`, `Data.JSON.{Keyword,Token,Number,Lexer,String}`, `Data.XML.{Escape,Token}`.
- All proofs (`parseJSON-printJSON`, `parseXML-printXML`, `jsonStage`, `xmlStage`, …) still check unchanged, and
  the printed SVG is byte-identical on the fixtures.

## Phase 3 — remaining opportunities (optional)
- GC is now the larger half of the run time: `tokenize` computes its fuel with `length cs`, which forces and
  retains the whole input list (~100 MB for 2.4 MB). A fuel-free formulation (or computing the fuel from the
  `String`'s length before `toList`) would let the list stream. It touches `tokenize-print`.
- `-with-rtsopts=-A128m` gives ~10% on the 2.4 MB file for ~0.5 GB RSS; not adopted.
- Element children are `Fin n → _`, so `mixed`/`lookup` cost O(i) per child i and an element with n children is
  O(n²) to print (noticeable beyond ~10⁴ children: 16 000 point features take 7.6 s). Fixing it needs a different
  child representation (or chunking) and is a design decision for the AST.
- `Data.List.upTo`/`applyUpTo` and `tabulate` are quadratic for the same reason; avoid them on long lists.
