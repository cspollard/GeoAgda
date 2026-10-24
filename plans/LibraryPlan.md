# Plan: the `parsnip` library

Status: **Step 1 done (2026-10-24).** Step 2 pending.

## Goal
Separate the parsing/printing code (JSON, XML, SVG) from the GeoJSON → SVG application so that it can be
imported as a library, with the dependency direction enforced: the library must not import `GeoAgda.*`.

## Step 1 — subdirectory library (done)
- `parsnip/` has its own `parsnip.agda-lib` (`depend: standard-library` only), `make-everything.sh` and `README.md`.
  Check it alone with `parsnip/make-everything.sh`; this proves it has no `GeoAgda` dependency.
- `GeoAgda.agda-lib` puts `parsnip/src` on its include path (no global library registration needed).
- Moved (with `git mv`, so history follows): `Data.Container.List`, `Data.JSON.*`, `Data.XML.*`, `Data.SVG`, and
  the invertible-syntax modules `GeoAgda.Parsing.Invertible.{Core,Char,Combinators}` → `Data.Invertible.*`.
- Renamed `Data.JSON.Stage` → `Data.Stage` (XML used it; it is not JSON-specific).
- Removed the compatibility shims `GeoAgda.Parsing.JSON.{Lexer,Parser}` and `GeoAgda.Parsing.Invertible.Number`;
  clients import `Data.JSON.*` directly. `GeoAgda.agda` still re-exports the library modules.
- Stays in the app: `GeoAgda.Model`, `GeoAgda.Rendering`, `GeoAgda.Pipeline`, `GeoAgda.Container.Combinators`
  (unused by the library; move it if it turns out to be generic), and all `GeoAgda.Tests.*`.
- The name `parsnip` was chosen by the user; renaming only touches the `.agda-lib`, the directory and the README.

## Step 2 — own repository (pending)
1. Move the library's tests out of `GeoAgda.Tests` into `parsnip/test` (the JSON/XML parts of `Milestone7`,
   `JSONRoundTrip`, `Milestone1–4` where they only use library modules); the app keeps pipeline tests.
2. Decide the name; register it in `~/.agda/libraries` (or add as a git submodule) and switch the app's `.agda-lib`
   from the `parsnip/src` include to `depend: parsnip`.
3. Split history: `git filter-repo --subdirectory-filter parsnip` into a new repo (or `git subtree split`).
4. Pin the stdlib version in both projects; move `plans/JSONPlan.md` and `plans/XMLPlan.md` to the library.
5. Remove `parsnip/` from this repo (or replace with the submodule).

## Later (optional)
- Unify the JSON and XML pipelines (shared tokenizer/stage plumbing).
- Pretty-printers; wider XML names (`isNameStart`/`isNameChar`).
