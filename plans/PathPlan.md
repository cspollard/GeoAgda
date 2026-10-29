# PathC plan

Goal: a compact intermediate form for map geometry, so that the renderer does not hold `JSONNumber` digit
lists for every vertex. Part of the memory item in `TODO.md`; do step 2 there (stream per group) first.

## Where things are today

- `JSON = JSONC ⋆ ⊥` and `XMLDoc = XMLC ⋆ ⊥`: free monads (finite trees) on the containers `JSONC`, `XMLC`
  (`Data.JSON.AST`, `Data.XML.AST`). Arrays and element children are `ListC = ℕ ▷ Pos`.
- A JSON number is a *shape* (data in the node, no positions); a JSON array is a node with one position per element.
- `GeoAgda.Model.GeoJSON.Extraction` decodes `JSON` into the record types (`Position`, `Geometry`, …).

## Design

    data PathShape = moveTo ℤ ℤ | lineTo ℤ ℤ | close        -- scaled ×10⁴, see Scaled.agda
    PathC : Container 0ℓ 0ℓ
    PathC = PathShape ▷ λ { (moveTo _ _) → ⊤ ; (lineTo _ _) → ⊤ ; close → ⊥ }
    Path  = PathC ⋆ ⊥                                      -- a ring is a chain of nodes

`PathC ⋆ ⊥` is a list of drawing commands: one position (the rest of the path) per command, none after `close`.
It is the same data as `formatRingD` walks over, with the coordinates as small integers.

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
   - **Handle** that into the free monad: a morphism `RingC ⇒ PathC ⋆ A` (each node expands into a small
     `PathC` tree). By the universal property of the free monad, a natural transformation `⟦ C ⟧ ⇒ M` extends to a
     monad morphism `C ⋆ ⇒ M`, so `RingC ⋆ ⇒ PathC ⋆` is `foldr` of the handler. This is the right kind of
     map: the handler is local and the global fold is free.
2. **Path → SVG is an algebra, not a morphism into `XMLC`.** The SVG path is one element whose `d`
   attribute is a single string, so it is `foldr` over `PathC ⋆ ⊥` with the algebra
   `⟦ PathC ⟧ String → String` (print one command, followed by the printed rest), then wrapped:
   `<path d="…" fill=… stroke=…/>`. After that the geometry is one `Text` blob, the most compact form there is.
3. **Colours and other path information are not part of `PathC`.** They come from the feature's properties via the
   style rules (`NaturalEarth.agda`: `classRules`, `depthColor`, …), exactly as now. The wrapper step takes
   `(properties, Path)` and builds the `XMLC` node (`d`, `fill`, `stroke`, `stroke-width`). If we want the
   structure to show it, a `StyledC` layer (`style ▷ Pos`: a shape with the attributes, positions = children) can sit
   on top of `PathC`, interpreted into `<g>`/`<path>` nodes by one more handler.
4. **The parser** is not itself an unfold into `JSONC ⋆`. It is a (partial) coalgebra over token streams
   (`Data.JSON.Parser`, with the round-trip theorem); the result happens to be a free-monad value. So `JSONC ⋆ A`
   is the shape of the output of a parse, not a one-step unfold of the `List Char`.

## Memory: what the containers do and do not buy

- The container structure gives modularity and proofs (`render ∘ decode ≡ formatRingD`, by induction on the chain).
- It saves memory only if the `JSON` tree is not built first: the decode must consume the parse
  lazily/fused, or the parser must target the ring container directly. A morphism applied after
  `parseJSON` has already materialised the whole tree saves nothing. That is why step 2 (stream per group)
  and the profile (step 1) come first.
- A balanced-tree-backed `ListC` (`Data.Container.Table`) costs more per node than a cons cell; for rings the
  chain form (`PathC`) is the lean one.

## Steps

1. Profile (`+RTS -s -hT`) and do the per-group streaming in `exe/Earth.agda`.
2. `GeoAgda.Rendering.SVG.Path`: `PathShape`, `PathC`, `Path`, `fromRing : List Position → Path`,
   `renderPath : Projection → Path → List Char`, with `renderPath p (fromRing r) ≡ formatRingD p r`.
3. Switch the SVG renderer from `Position` lists to `Path` for polygon rings; keep `Geometry` as the public type.
4. Only then try a direct `List Char → Path` parse for the large band files, and measure.
