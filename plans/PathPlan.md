# PathC plan

Goal: a compact intermediate form for map geometry, so that the renderer does not hold `JSONNumber` digit
lists for every vertex. Part of the memory item in `TODO.md`.

**Order of work.** We do this *before* per-group streaming (`TODO.md` memory step 2). Streaming writes each
group out and forgets it, which rules out any later operation that needs the whole dataset in hand
(cross-group passes, simplification, bounding boxes, reordering, re-projection). `PathC` keeps the data in
memory but small, so those operations stay possible. Streaming remains an optional, composable step afterwards
if the measured peak is still too high.

## Where things are today

- `JSON = JSONC ⋆ ⊥` and `XMLDoc = XMLC ⋆ ⊥`: free monads (finite trees) on the containers `JSONC`, `XMLC`
  (`Data.JSON.AST`, `Data.XML.AST`; `_⋆_` is `Data.Container.FreeMonad`). Arrays and element children are
  `ListC = ℕ ▷ Pos`.
- A JSON number is a *shape* (data in the node, no positions); a JSON array is a node with one position per element.
- `GeoJSON.Extraction` decodes `JSON` into the record types. `Position` holds two `JSONNumber`s.
- `Projection = Position → ProjectedPoint` (a pair of `String`s), applied while printing
  (`PathData.formatRingD`). `Scaled.agda` has `jsonNumberToScaledℤ` and `scaledℤToJSONNumber` (×10⁴, lossy).
- Rounding today is a *geometry pass*, not a print option: `Compose/Earth.agda` `simplify` calls
  `Model/GeoJSON/Simplify.agda` (`--precision`, default 0.01°, `0` = untouched), which snaps coordinates to a grid,
  removes repeated and exactly collinear vertices, and (bathymetry) thins vertices by distance. The fixtures have up
  to 15 fraction digits (Natural Earth).

### The pipeline today (`exe/Earth.agda`, `Compose/Earth.agda`)

Per layer file (`loadLayer`): `readFile` → `parseJSON` (the whole `JSON` tree) → `extractLocatedFeatureCollection`
(all features decoded to `Geometry`/`Position`, two `JSONNumber` digit lists per vertex) → `applyLayer`, which maps
the layer's `convert` over the features. `convert` is mostly `rebuild (roundGeom o)` or, for bathymetry,
`rebuild (bathyGeom o)`, i.e. `Simplify.simplifyGeometry` (snap, drop repeated/collinear vertices, thin) plus a
property rewrite; degenerate features are dropped. `weight` then forces the result so that the file's text and
`JSON` tree can be collected. Then `Group.finish` per group, concatenation of all groups into one `List Feature`,
`renderMapSVG`, `renderXML`, one `writeFile`.

Peak ≈ (the largest file at full resolution: text + `JSON` + decoded `Position`s) + (all *reduced* features loaded so
far). The second term is what grows and is held until the final `writeFile`. `Path` shrinks it. The first term is
inherent to "parse, then decode, then reduce" and goes away only with a fused parse (step 6).

## Target pipeline

    read → parseJSON → extract → reduce+convert → Path → (kept) → renderPath

`reduce+convert` is one left-to-right fold over a ring's positions (snap, drop repeated and collinear vertices,
radial thinning; state = the last one or two kept vertices) whose output is the `Path`. Full-resolution
`Position`s never become a retained structure; the old `Simplify.simplifyGeometry` is the *specification*, and the
fold is an optimisation of it: same result, cheaper. Reduction runs on machine-size integers rather than
`JSONNumber`↔scaled conversions (the stdlib `ℤ` operations are slow, see `Scaled.agda`), dropped vertices are never
projected or printed, and it is a single pass.

When `--precision > 0` the reduction snaps the *stored* coordinates (that is how coinciding vertices become
duplicates that can be dropped). Stored values then sit on the grid and print with few digits by themselves, so
`renderPath` takes **no** rounding argument for geographic coordinates. With `--precision=0` nothing is reduced and
the stored coordinates are exact. (Rounding at render time makes sense later, for *projected* coordinates after a
non-linear projection such as Equal Earth.)

Collinearity multiplies coordinate differences, which overflows a machine word at scale 10¹⁵. When the grid is
`g > 0`, run the reduction on grid units (`value / g`, small integers) and multiply back when emitting.


## Design

    data PathShape = moveTo ℤ ℤ | lineTo ℤ ℤ | close | stop
    PathC : Container 0ℓ 0ℓ
    PathC = PathShape ▷ λ { stop → ⊥ ; _ → ⊤ }          -- one position (the rest of the path), none after `stop`
    PathM A = PathC ⋆ A                                  -- a path fragment that continues into A (cf. `XMLM`)
    Path    = PathM ⊥                                    -- a complete path: explicitly stopped, no leaves

Smart constructors (`moveTo`, `lineTo`, `close`, `stop`, each a one-node `PathM A`) and the monad instance give
`do` notation:

    ring    : List Position → PathM ⊤         -- may be empty: `pure tt`
    polygon : List (List Position) → PathM ⊤  -- the rings in sequence: `foldr _>>_ (pure tt) ∘ map ring`
    finish  : PathM ⊤ → Path                  -- `p >> stop`

Reading: `PathM ⊤` is a fragment that more can follow; `PathM ⊥` is complete and cannot be extended (`>>=` on it
is vacuous). `renderPath` is defined on `Path` only, so an unfinished fragment cannot be rendered and the
algebra has no leaf case.

Decisions (these fix gaps in the first draft):

- **Coordinates are geographic and exact, a fixed decimal scale (lon, lat), not projected.** A coordinate is
  an `ℤ` counting units of 10⁻¹⁵° (`Scale = 10¹⁵`). A GeoJSON number is a decimal, so this is exact for every
  number with at most 15 fraction digits once its exponent is applied; the fixtures top out at 15. 180·10¹⁵ is
  below 2⁶³, so each value is still one machine word in GHC's `Integer`, and widening the scale from ×10⁴ costs no
  extra memory. A number with more than 15 fraction digits is *rejected* at conversion rather than rounded, so there
  is no silent loss; step 2 checks that no real file (Natural Earth 10m, the ETOPO bands) needs more.
  The projection is applied at render time, as `formatRingD` does now, so the stored `Path` is projection-independent
  and several projections can be rendered from one `Path`. `renderPath` converts each `ℤ × ℤ` back to a `Position`
  (exact, trailing zeros trimmed) and then calls the projection.
- **Rounding is part of reduction, not of printing** (see "Target pipeline"): there is no grid argument to `renderPath`.
- **`close` continues, `stop` ends.** With a position-free `close` and leaf `⊥`, the empty ring would not be
  representable and rings could not be joined (`>>=` replaces leaves, a `⊥`-leaf path has none; `map absurd`
  changes the type but not that). With `close` continuing, a polygon is the bind of its rings and a multipolygon
  the bind of its polygons, in one `d` string. `stop` is the only node without positions, so it is the only way
  to build a `PathM ⊥`. (`PathM ⊥` is isomorphic to a `List PathShape` with a terminator; the container form
  earns its keep through the handler and algebra maps below and the proofs.)
- **The type does not enforce well-formedness.** `moveTo … lineTo … stop` without `close`, or a `lineTo` before
  any `moveTo`, is legal. GeoJSON rings never produce these; if we want the invariant, add a predicate on
  `Path` later. Out of scope here.
- **Printing.** Commands are joined by a single space, `M x,y L x,y … Z`, exactly what `formatRingD` and
  `formatPolygonD` emit. `stop` prints nothing.

### Theorems

Writing `⟦ q ⟧ = renderPath proj (finish q)`:

1. **Concatenation is a homomorphism**: `⟦ p >> q ⟧ ≡ ⟦ p ⟧ ++ ' ' ∷ ⟦ q ⟧` when both are nonempty (and `⟦ pure tt ⟧ ≡ []`),
   by induction on `p`. This is the semantics: rendering sends `>>=` to string concatenation.
2. **Ring**: `⟦ ring r ⟧ ≡ formatRingD proj (map canon r)` for `r ≠ []` with exactly-representable
   coordinates. `canon` is `Position`'s normal form (round trip through the scaled integer: trailing zeros trimmed,
   exponent folded); it preserves the number's value, and is the identity on an already-canonical `Position`.
3. **Polygon / multipolygon**: from 1 and 2, matching `formatPolygonD` / `formatMultiPolygonD` on nonempty rings.
   (`formatPolygonD` would insert a double space for an empty ring; the empty ring is simply no commands.)

## The maps, and what kind each one is

1. **JSON → Path is not a container morphism `JSONC ⇒ PathC`.** A morphism `(u , f) : S ▷ P ⇒ S′ ▷ P′` chooses
   the output shape from the *input shape only* and routes each output position to one input position.
   Two things break that:
   - a coordinate pair `[x, y]` is an array node whose numbers sit in the *children's* shapes, so a
     `moveTo x y` shape cannot be chosen from the array node alone;
   - an array of `n` points has `n` positions while a `lineTo` has one (the rest of the path), so the
     list has to become a chain, not a node.
   What works is two steps.
   - **Decode** with the schema that exists already (`GeoJSON.Schema`, `Data.JSON.Conformance`): `⟦ S ⟧` for the
     coordinate schemas. The decode produces a container whose shapes *do* carry the numbers, e.g.
     `RingC = ℕ ▷ Pos` over a shape `PointShape = ℤ × ℤ`.
   - **Handle** that into the free monad: a morphism `RingC ⇒ PathM A` (each node expands into a small
     `PathC` tree). By the universal property of the free monad, a natural transformation `⟦ C ⟧ ⇒ M` extends to a
     monad morphism `C ⋆ ⇒ M`, so `RingC ⋆ ⇒ PathC ⋆` is `foldr` of the handler. This is the right kind of
     map: the handler is local and the global fold is free.
   The first implementation can skip the container-valued decode and go `List Position → PathM ⊤` (`ring`), via
   `Extraction`. The decode-and-handle route is the later refinement (step 6).
2. **Path → SVG is an algebra, not a morphism into `XMLC`.** The SVG path is one element whose `d`
   attribute is a single string, so it is `foldr` over `PathC ⋆ ⊥` with the algebra
   `⟦ PathC ⟧ (List Char) → List Char` (print one command, then a space and the printed rest unless the rest is
   empty; `stop` prints nothing), then wrapped: `<path d="…" fill=… stroke=…/>`. After that the geometry is one `Text` blob, the most
   compact form there is.
3. **Colours and other path information are not part of `PathC`.** They come from the feature's properties via the
   style rules (`NaturalEarth.agda`: `classRules`, `depthColor`, …), exactly as now. The wrapper step takes
   `(properties, Path)` and builds the `XMLC` node (`d`, `fill`, `stroke`, `stroke-width`). If we want the
   structure to show it, a `StyledC` layer (`style ▷ Pos`: a shape with the attributes, positions = children) can sit
   on top of `PathC`, interpreted into `<g>`/`<path>` nodes by one more handler.
4. **The parser** is not itself an unfold into `JSONC ⋆`. It is a (partial) coalgebra over token streams
   (`Data.JSON.Parser`, with the round-trip theorem); the result happens to be a free-monad value. So `JSONC ⋆ A`
   is the shape of the output of a parse, not a one-step unfold of the `List Char`.

## Memory: what the containers do and do not buy

- The container structure gives modularity and proofs (the theorems above, by
  induction on the path).
- It saves memory only if the big intermediate values are dead by the time the next stage runs. A `Path` is a
  chain of cons-like nodes holding two small integers each, against two digit lists per `Position` now.
  Converting a file's features to `Path`s straight after its parse lets the `JSON` tree and the file's `List Char`
  be collected before the next file is read, so the peak becomes (all `Path`s) + (one file's `JSON`), not
  (all `Position`s) + (all `JSON`). Only a parse that targets `Path` directly (step 6) removes the `JSON` term.
- A balanced-tree-backed `ListC` (`Data.Container.Table`) costs more per node than a cons cell; for rings the
  chain form (`PathC`) is the lean one.
- Bytes per vertex of the *result* is the number to watch: a `ℤ` is a boxed `Integer` in MAlonzo, so a
  `moveTo`/`lineTo` node may still be sizeable. Measure it (step 1) before assuming a win; if it is not enough, a
  packed representation (one `Integer` per vertex, or a `Text`/byte-array backed chunk) is the next move, and the
  `Path` interface (`ring`, `finish`, `renderPath`, bind) should hide it.

## Baseline (before `Path`, `--precision=0` with the elevation bands and lake depths)

`bin/Earth +RTS -s`: **6.68 GB maximum residency, 17.5 GB total memory in use** (copying GC), 130 s CPU of which
80 s GC (216 s elapsed), 341 GB allocated. GC dominates; the retained term, not the loader, is the problem.
Measure further runs with `-c -M<cap>` (compacting collector, hard heap cap) so a run cannot take the machine.

## Status (2026-10-30)

Done and typechecking (whole repo): `GeoAgda.Model.Exact` (exact ×10¹⁵ coordinates; digits beyond the 15th are
*rounded*, not rejected, because Natural Earth has 16–17 digit numbers), `GeoAgda.Model.Path` (`PathC`, `PathM`,
`Path`, `ringK`/`ringsK`/`ringP`/`polygonP`, `pathRings`), `GeoAgda.Rendering.SVG.Path` (`renderWith`,
`renderPath`), `Path.Properties` (proved: `ring-≡`, `polygon-≡`, `ringP-≡`, `polygonP-≡`, and the monoid laws
for `_⋄_`), `GeoAgda.Model.GeoJSON.Reduce` (`reduceGeometry`, `exactGeometry`: polygons become `pathG`), and
the `pathG` constructor wired through `Render`, `Centroid`, `Compose.labelPoint`, `exe/Earth`, `exe/Profile`
and `Compose/Earth.simplify`. Tests (`Tests/Path.agda`): exact conversion, rounding, ring rendering, and that
`reduceGeometry` keeps the vertices `Simplify` keeps. `Makefile` now links `bin/Earth` with `-rtsopts`.

Not done: step 5, the comparison. **Result so far is inconclusive.**

- With `Path`, the full run at `--precision=0` hit the heap cap before finishing: at 4 GB (compacting GC) it stopped
  loading `bathymetry_2200`; at 5 GB it got through `bathymetry_5000`. The baseline finished at 6.68 GB residency
  (copying GC). So no saving is shown, and the first version was worse than it needed to be: `finish` is built with
  `_>>=_`, which rebuilds every node lazily and keeps the unfinished path alive. `polygonP` builds the complete
  path directly; use it, not `finish (polygon …)`, on large data.
- (Correction: an earlier reading of a coarse `-hT` profile ("the transient dominates") was wrong; that profile took
  8 samples and missed its peak. The numbers below replace it.)

### Loader profile (`bin/Profile <stage> ne_10m_bathymetry_G_4000.json`, 23 MB, 3 GB cap, compacting GC)

| stage | max residency |
|---|---|
| read (`toList` of the text) | 948 MB (≈ 41 B per character: the whole `List Char` is live) |
| tokenize | 1.22 GB |
| parse | 1.22 GB |
| extract | 948 MB |
| convert (`exactGeometry`) | 948 MB |

So the transient for the largest file is about 1 GB, and the file text as a `List Char` is the biggest part of it.

### Retained size per vertex (same file, live heap with only the geometry kept: `Profile keepG` / `keepP`)

`Position` geometry **467 MB**, `Path` **58 MB**, for about 500 000 vertices: **≈ 930 B → ≈ 114 B per vertex, 8× smaller.**
This agrees with the baseline: ≈ 6.5M vertices × 930 B + ≈ 1 GB transient ≈ the measured 6.68 GB.

### Leaks found and fixed

1. **`rebuild` kept the source feature alive.** `rebuild … (λ _ → Feature.properties f)` (band layers, lake depths,
   regions) left the new feature's properties an unevaluated thunk holding the source feature `f` and its
   full-resolution `Position`s. `rebuild` now forces them with `Function.Strict` (`feature nothing g $!′ props g`).
   Single-file profiles were clean both before and after, so this alone did not explain the run-away heap.
2. **The shape of `loadLayer` kept every loaded file's source alive until the whole load finished.** With
   `case parseJSON … of … extractLocatedFeatureCollection … of … say … >> pure feats` inside the IO continuation,
   each file's text, `JSON` tree and `Position`s stayed reachable (about 270 MB per 5 MB file, released all at once
   when the load ended), however much was forced. Making the per-file work a *pure function of the file's text*
   (`convertText`, using `with`) and letting the IO step see only its result removes it. Found by reproducing the
   chain in `bin/Profile` (`chain*` stages) and varying one thing at a time; the retainer profile (profiling build)
   named `Maybe._>>=_` and `Product.map` closures but could not be mapped to call sites. Ten band files at
   `--precision=0`: peak residency 2.85 GB → 1.40 GB.

### Result

Full `--precision=0` run with the ETOPO bands and lake depths, compacting GC, 4 GB cap (the baseline needed
6.68 GB residency): **loading now completes** with a live heap of about 1.1–1.2 GB (the baseline reached ≈ 6 GB by
the end of loading), 4735 features composed. The run then **exhausts the 4 GB heap while rendering**: the live heap
grows from 1.2 GB to 3.9 GB and is almost all list cells (3.4 GB of `:`), i.e. the 194 MB SVG built as a `List Char`
(≈ 41 B per character). GC dominates the time (383 s of 439 s with `-c`).

So `Path` plus the two fixes removes the loading problem. The next bottleneck is the output: `renderXML` produces the
whole document as a `List Char` for one `writeFile`. That is a separate, later stage (after all the data operations),
so writing it in chunks (`appendFile` per element, with the header and closing tag around them) does not preclude
any operation on the data.

## Steps

1. **Baseline** (small): `+RTS -s -hT` on a run of `bin/Earth` as is, so we know what to beat; record the peak and,
   if the heap profile separates them, the transient (one file) and retained (reduced features) terms. No code
   changes beyond what the RTS flags need.
2. `GeoAgda.Rendering.SVG.Path`: `PathShape`, `PathC`, `PathM`, `Path`, the smart constructors and monad instance,
   `ring`, `polygon`, `multiPolygon` (via bind), `finish`, `renderPath : Projection → Path → List Char`, with
   `Scale = 10¹⁵`. First check the fraction-digit count of the real inputs. Prove the three theorems.
3. **Fused reduce+convert**: `GeoAgda.Model.GeoJSON.Reduce` (or in `Path`), a one-pass fold from a ring/line's
   positions to a `PathM ⊤` that does what `Simplify` does, on integers (grid units when `g > 0`). Specification
   is `Simplify`: test that, for the fixtures and a real Earth run, `render ∘ reduceRing ≡ formatRingD ∘ ring`
   (byte-identical SVG, up to `canon`). Prove the easy pieces (snap idempotent, dedupe), leave collinear and
   thinning to tests.
4. **`Feature` carries a `Path` for polygon rings.** First read `Group.finish`, `Centroid` and `ViewBox`, which read
   `Geometry`; the `Path` is built after `finish`, or the feature carries both until they are ported. `Geometry`
   stays the public type. The `JSON` of a file is dropped at the point of conversion.
5. Re-run the step 1 measurement. Decide whether the saving is enough, whether a packed representation is needed
   (see Memory), or whether streaming per group (`TODO.md` memory step 2) should now be added.
6. Only then try the container-valued decode plus the handler `RingC ⇒ PathM`, and a direct `List Char → Path`
   parse for the large band files, and measure.

## Output memory: the SVG text (open, 2026-10-30)

Full `--precision=0` run: loading is fixed (live heap about 1.2 GB), then *rendering* exhausts a 4 GB heap. The live
heap grows from 1.2 GB to 3.9 GB, 3.4 GB of it `:` cells, i.e. evaluated `List Char`, not thunks. The 194 MB SVG is
materialised as a `List Char` (about 41 B per char). The `Path` fold itself is lazy and is not the leak.

Two candidates, not yet separated (they may add up):

1. the SVG AST keeps every `d` attribute as text, all live at once;
2. the serialiser builds the whole document as one `List Char` for a single `writeFile`.

Part of the pipeline may already be `String`: `renderGeometry` calls `String.fromList` on the `d` attribute, so the
remaining cost may be the transient `List Char` of one large feature, or the final concatenation. Check before
changing types.

**Measure first** (`+RTS -hT`): residency after the AST is built and forced, after serialisation, after the write.
AST already about 2 GB means the AST text is the problem; only the serialiser balloons means chunked output is enough.

### Remedy A: write the output in chunks

`<svg>` header, one `appendFile` per element (or group), closing tag. Peak is the largest element. Rendering is a
separate stage after every data operation, so this precludes none of them (unlike streaming the *data*).

### Remedy B: store `String` payloads (`Data.Text`, about 1–2 B per char instead of 24–40)

Constraint: everything stays `--safe --cubical-compatible`, and `List Char` payloads, as now, remain fully supported
and proved. Only a map *to* `String` payloads is added, for memory.

- The round trip `toList (fromList cs) ≡ cs`, `fromList (toList s) ≡ s` is not provable under `--safe`. The stdlib
  has it in `Data.String.Unsafe` (`--with-K`, `TrustMe`), which would infect everything above it. Do **not** import it
  in the library.
- Instead make the assumption an *argument*: a record of the payload type with `toList`, `fromList` and the two laws
  (a `TextIso`). `List Char` is the safe instance (`id`, `refl`). `String` is the instance with `trustMe`, supplied
  only by the executables (not `--safe`). All theorems stay checked, generically in the instance; the assumption sits
  in one auditable place.
- **Does this make XML et al. parametric in the payload?** Yes, if the saving is to apply to the whole AST: `XMLShape`,
  `XMLC`, `XMLM`, `XMLDoc` (and the SVG layer on top) take the payload type `P` with its `toList`, so the validity
  predicates (`isValidName`, `isValidAttrs`, `isValidTexts`) run on `toList p` (O(n) per use, but only evidence).
  Instantiating `P = List Char` gives today's definitions, so the current code and proofs are the special case.
- A map `XMLM (List Char) → XMLM String` after the fact does *not* save memory by itself: the `List Char` tree is
  already built. It helps only if the conversion happens per element before the elements are accumulated (which is
  Remedy A again), or if the renderer builds `String` payloads directly.
- Cheaper variant to try first: make only the large payload (the path `d` attribute) a `String`, not the whole AST.
  The renderer produces the `d` text in bounded chunks and `fromList`s each, so no transient `List Char` exceeds one
  element. No parametricity needed beyond that field.

### Order

1. the three-point `-hT` measurement; 2. Remedy A (cheap, local, composes with B); 3. B in its cheap variant; 4. full
parametric payload only if (3) is not enough or other payloads (names, text) turn out to matter.

### Measurement: where the SVG text lives (2026-10-30)

`bin/Profile` stages `renA`…`renH`, run on the three biggest band files (`bathymetry_1000/1500/2200`, 25 MB of
JSON, 24.5 M characters of path text), `-hT -i0.3 -M3g`. "Features" is the live heap of the loaded features alone
(`chainF`: 1.23 GB max residency, STACK 344 MB; the harness itself recurses, so every stage carries that).

| stage | what it does | max residency | STACK |
|---|---|---|---|
| `chainF` | load only | 1.23 GB | 344 MB |
| `renD` | `length (renderPath …)` per feature, no AST | 1.29 GB | 421 MB |
| `renF` | the same through `toList (fromList …)` (the AST's `String`) | 1.25 GB | 494 MB |
| `renG` / `renH` | `escapeValue` / `fixText` of the path text | 1.30 GB | 485 / 426 MB |
| `renE` | build the document, `length (printTokens doc)` | 1.20 GB | 412 MB |
| `renA` | build, then stream `length (printXML doc)` once | **heap exhausted at 3 GB** (1.54 GB live) | 706 MB |
| `renB` | the document kept live across two prints | exhausted (1.46 GB live) | 613 MB |

Findings:

- The `Path` fold is not the problem: 24.5 M characters through `renderPath`, through `String`, through `fixText` and
  `escapeValue`, add nothing to the heap.
- The AST is not the problem either. `renB` (document live across two prints) is no bigger than `renA` (document used
  once), and the `d` attribute is already a `String` (`Render` calls `String.fromList`), so the AST holds compact
  text and `toList` regenerates it lazily. The `String`-payload idea (Remedy B, and parametric XML) would save little
  now: not needed for `d`.
- `renE` (the token list, built lazily) is cheap, so the cost is in *printing the one big token list*: `printXML`
  adds about 250–300 MB of STACK and 110 MB of BLACKHOLE on top of the loaded features for 24.5 M characters
  (about 10–16 B per output character; extrapolated to 194 M characters that is 2–3 GB, which is the failure seen
  on the full map). Deep stack plus BLACKHOLEs means evaluation is nested per character or per element, not
  streaming. The exact function is not pinned down (`concatMap`/`++` and `Table` traversal in `Data.XML.Tokens`
  are the suspects).
- Caps: with the copying collector the live heap must stay below half of `-M`, hence "exhausted at 1.5 GB live";
  use `-c` for honest caps.
- Also seen: about 130 MB of `jsonNumber` is still live in `chainF` after loading, so some source JSON is still
  reachable in this harness; worth a look once rendering is fixed.

Conclusion: do Remedy A (chunked output) first. It removes the whole-document token list and print, whatever the
exact culprit, and composes with everything else. Remedy B and a parametric payload type are dropped unless
chunking leaves a text problem.

### Chunked output: implemented and measured (2026-10-30)

`Data.XML.Chunks.xmlChunks` splits the printed root element at its children (start tag + leading text, each child
with the text after it, end tag); `exe/Earth.writeChunks` does `writeFile out ""` and then one `appendFile` per chunk.
`concat (xmlCharChunks d) ≡ printXML d` is checked on examples (`GeoAgda.Tests.Chunks`, `refl`); the general statement
is not proved. Each feature is one chunk, so a chunk is as large as the biggest feature's path (it is printed
lazily and packed into a `String` as it is consumed).

Full map, `bin/Earth --precision=0 natural-earth-geojson out.svg +RTS -c -M4g`: **completes** (before: heap
exhausted at 4 GB while rendering). 8313 features, 104 MB SVG, 102 s wall (GC 61 s of 94 s CPU), max residency
2.5 GB, 4.2 GB total memory in use under `-c`; `xmllint --noout --huge --stream` reports it well formed.

Not verified: byte equality with the pre-chunking output (that binary was overwritten; the equality of the chunks
with `printXML` is the argument); the default-precision path end to end. The residency (2.5 GB) is still above the
loaded features (about 1.2 GB), so rendering still holds something per feature; the same `-hT` stages
(`renA`…) can be used to find it, and the retained JSON numbers noted above are the other suspect.
