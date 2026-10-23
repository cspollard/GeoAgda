# Agda MCP — feedback from the JSON refactor (Phases 0–4)

Based on what I actually used in this session: `agda_load_and_goals` (~30 calls), `agda_search_library` (3),
`agda_get_module_summary` (2). I did **not** use `agda_hole_action`, `agda_unify_with_hole` or
`agda_get_symbol_implementation` — see "Why I mostly edited files" below, which is itself feedback.
I have not measured wall-clock time (the tool doesn't report it), so the performance notes are impressions.

## What worked well

- `agda_load_and_goals` is a good inner loop: status + open holes + warnings/errors in one JSON blob, with hole
  goals shown as types. For files with a handful of holes it was exactly what I needed.
- Typechecking was fast enough that I never reached for the CLI for speed; I only used the CLI when the MCP failed
  (below) and to check modules that import the file I changed.
- Warnings and errors carry file/line/column, which made them easy to act on.

## Problems, most important first

1. **Goals and errors are printed fully normalised, which can be enormous.** A single hole in `Data.JSON.Number`
   (a goal mentioning `natToDigits i`) came back as ~4,000 tokens of unfolded `Data.Nat.DivMod` / well-founded-recursion
   internals; a unification error in `Data.JSON.String` was ~3,500 tokens of `map′ … toℕ-injective …` terms. That is
   the dominant token cost. Suggestions:
   - a `normalisation` parameter (`AsIs` / `Simplified` / `Normalised`, as in Agda's `C-u C-c C-,`), defaulting to
     `Simplified` or `AsIs`;
   - a `max_chars` / `max_depth` cap that elides subterms with `…`;
   - for errors, cap each embedded term and report "N more characters elided".
2. **The index is incomplete and search returns nothing.** `agda_get_module_summary` said "not found in index" for
   `Function.Bundles` and `Data.Container.Relation.Binary.Equality.Setoid` — both exist in the stdlib on disk and are
   central. `agda_search_library` returned `[]` for three reasonable queries (container equality over a setoid; `toList
   (fromList cs) ≡ cs`; the `LeftInverse` record). I fell back to `grep` over `~/agda-stdlib/src`, which worked but
   defeats the purpose. Suggestions: index the whole stdlib (and `agda-categories`) including bundles and records;
   fall back from semantic search to name/substring search; return "did you mean" module names; say explicitly whether
   a miss means "not indexed" or "no match".
3. **An opaque failure: `Error executing tool agda_load_and_goals: 'id'`.** It happened on two consecutive calls for
   `Data.JSON.Goals` (right after the file was created) and then stopped on its own after I ran the Agda CLI on the
   same file. It looks like an internal `KeyError`; the cause is unknown to me. Please surface the underlying Agda
   message, or at least say "response had no `id`" and whether retrying is safe.
4. **`code_patch` can't patch.** The parameter is documented as "a small replacement for the file's *whole*
   contents (max 1000 chars)". That makes it unusable for real files, and a lemma-sized change means rewriting the file
   on disk. What I wanted: "typecheck this declaration in the context of file F without editing F" (a scratch
   module that imports F's scope), or a true patch (`old`/`new`).
5. **No way to ask about a term in file scope.** `INFER_TYPE` / `COMPUTE_NORMAL_FORM` exist only through
   `agda_hole_action` on a hole. I often wanted `infer_in_file(file, expression)` — e.g. "what is the type of
   `Composition.rightInverse`" or "does `'t' ≟ 'n'` reduce".
6. **Open holes carry no position.** `open_holes` gives `hole_id` and `type`, but not line/column, and ids are
   renumbered after every edit. With 8–14 holes I had to correlate by type text. Please add `line`, `column`, the
   enclosing definition name, and the local context (as an opt-in, since it can be large).

## Token efficiency

- The same pre-existing warnings were returned on every load of a broken dependency (e.g. `Soundness.agda`'s
  `ModuleDoesntExport` block, ~700 tokens each time). Suggest `since_last_load: true` / return only new diagnostics, or
  collapse repeats.
- Return `open_holes` as a compact list by default (`id`, `line`, short type, truncated at ~200 chars) with a separate
  `get_goal(hole_id)` for the full type and context.
- `status: "ok"` is returned for files with open holes; `"incomplete"` would be less ambiguous.
- Unsolved *non-interaction* metas ("Unsolved metas at the following locations") showed up in the CLI but I never saw
  them from the MCP (the one time I hit them the MCP call itself was failing, so I can't tell if they're reported).
  Worth reporting as a warning.

## Ergonomics

- **Why I mostly edited files:** the hole-action loop (`REFINE` / `CASE_SPLIT` / `GIVE`) writes into the file, but the
  proofs here were `with`/`rewrite`-heavy over stdlib `Dec` and `Maybe`, where I needed to control abstraction
  (`in eq`, helper lemmas to avoid `with` capturing the goal). That was easier by editing the file directly and
  reloading. A `CASE_SPLIT` that can emit a `with … in eq` clause, or a "generalise over expression" action, would
  have kept me in the tool.
- No project-level check. I had to leave the MCP to confirm that the rest of the library still loads after moving
  `JSONNumber` (CLI on `Pipeline`, `exe/Main`, etc.). A `agda_check_modules([...])` that returns a one-line verdict per
  module, or `agda_check_project`, would be a good addition.
- No timing and no cache information in responses (`elapsed_ms`, "reused interface for N modules") — useful for
  deciding how much to batch.

## Performance

- Single-module loads felt quick. I can't quantify it. The cost I did notice was the response size, not the latency.
- Because I could not see per-call timings, I could not tell whether a slow call was Agda or the server. Please add
  `elapsed_ms`.

## Wish list, in priority order

1. Normalisation / truncation controls on goals and errors.
2. Complete index + name search fallback + honest "not indexed" messages.
3. Positions and local context for holes (opt-in).
4. `check_declaration` in file scope (scratch module) and `infer_in_file`.
5. Diagnostics diff / dedup across loads.
6. Project-level check and timings.
7. A readable error for the `'id'` failure.
