---
name: explore-codebase
description: Map an unfamiliar codebase into browsable notes that follow the program flow — an overview (problem + solution), an architecture walk of the main flow with a one-liner and wikilink per invoked method, and one file per method (code or explanation, plus an input→output example) linked recursively down the call graph. Use when exploring a new/unfamiliar codebase, onboarding to a repo, or when asked to "map", "explore", or "understand" a codebase.
---

# explore-codebase

Build a **map of an unfamiliar codebase**, not a review of it. The goal is an
accurate mental model, fast. Follow the program flow; go deep on the spine and
shallow everywhere else.

This skill **reads and writes notes only**. It never edits the target code.

## The reader

A junior developer who knows the technical terms. So:

- **Be concise.** Don't explain what a mutex or a closure is. Name the thing.
- **Prefer showing code over describing it** when the code is straightforward.
  Paste the relevant lines (trimmed, `...` for elisions) instead of narrating them.
  **Every snippet must be cleanly formatted.** The notes are never saved by the
  reader, so no formatter-on-save runs — you format at write time. The reliable
  way: copy the lines **verbatim from the source** (already formatted by the
  project's own tooling) and keep that exact indentation when you trim. Don't
  re-indent, re-wrap, or reflow a fragment by hand — dedent the whole block to
  the fence as a unit so relative indentation is preserved. Tag every fence with
  its language (` ```ts `, ` ```py `) so the reader gets highlighting.
- **Prefer an explanation over code for complex algorithms** — the tricky sort,
  the state machine, the recursive descent. There, prose beats a wall of code.
- **Every function that can have one gets a simple input → output example.**
  This is the reader's main way of understanding. Don't skip it.
- **Follow the program flow.** The reader thinks in execution order. Don't
  reorganise by file or by alphabet — walk the code the way it runs.

## The frame (do it in this order)

1. **Problem** — what does this system exist to do?
2. **Solution** — how, at a high level?
3. **Architecture** — file tree + the main program flow.
4. **The spine** — trace the happy path down through the call graph, one method
   at a time, recursively.

Happy path only. Skip error handling, edge cases, and defensive branches — this
is exploration, not review. Go deep on the main flow; skim or skip everything
off it.

## Where notes go

**Always** write to a **feature folder** under the central Codebases directory —
never into the target project itself:

```
~/Developer/reader/Codebases/<project>/<feature>/
  overview.md          # problem + solution, high level. The entry point.
  architecture.md      # file tree + main program flow with one-liners + wikilinks
  functions/
    <methodName>.md    # one per method on the spine, linked recursively
```

- `<project>` — kebab-case name of the target codebase (usually its root
  directory or repo name).
- `<feature>` — kebab-case name of the specific flow/area being mapped
  (e.g. `auth-login`, `checkout`, `request-pipeline`). One exploration = one
  feature folder. If the user didn't name the feature, infer it from what
  they're exploring, or ask in one line if it's ambiguous.

A codebase can have several feature folders under it, one per flow explored.

If the feature folder already exists, this flow has been mapped before — read
what's there and update/extend rather than starting over. If sibling feature
folders exist under the same `<project>`, skim their `overview.md` first so the
new notes stay consistent and can cross-link with `[[wikilinks]]`.

## Steps

### 1. Orient (fast)

Read, in this order, only enough to get the shape:

- README / docs
- the package manifest (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, …)
  — dependencies tell you what kind of system this is
- the **data model / schema** — the core types are the fastest way in
- the **main entry point** — `main`, the server bootstrap, the CLI handler

Also note the **external boundaries**: where the system talks to a DB, the
network, the filesystem, other services. These anchor the map.

### 2. Write `overview.md`

```md
# <Codebase Name>

> mapped: <YYYY-MM-DD> · root: <path>

**Problem** — what this exists to do, in a sentence or two.

**Solution** — how it does it, at a high level. 3–6 sentences.

**Core data** — the central types/objects and what they represent.

**Boundaries** — where it touches the outside (DB, network, fs, other services).

**Start here** — the main entry point: `/abs/path/to/project/src/file.ext` → [[entryMethod]]
```

**Every path to the target code is absolute.** The notes live in a different
directory from the code, so relative paths don't resolve or click through. Write
the full path — `/Users/you/dev/project/src/file.ext:42`, not `src/file.ext:42`.
Set `root:` above to the target codebase's absolute root. (This applies only to
references to the _target code_; `[[wikilinks]]` between notes stay bare, since
they resolve within the notes folder.)

### 3. Write `architecture.md`

```md
# Architecture

## File tree

<the tree, annotated — one short note per dir/key file about its role>

## Main flow

Walk the happy path from the entry point, in execution order. Each step is the
invoked method, a one-line gloss, and a wikilink:

1. [[entryMethod]] — accepts the request and kicks off X
2. [[parseInput]] — turns the raw body into a `Foo`
3. [[handleFoo]] — the core work; see its file for the breakdown
   ...
```

Keep the file tree annotated but brief — a role per directory, not per file.

### 4. Write one file per spine method — recurse

For each method on the main flow, create `functions/<methodName>.md`:

```md
# methodName

> `/abs/path/to/project/src/file.ext:line`

One-line purpose.

**Params** — one line per parameter, with its **shape expanded**, not just its
type name:
```

- order: Order → { id: string, items: LineItem[], total: number, status: "open" | "paid" }
- opts: { retries: number, timeout: number }

````

Rules for shapes:
- **Expand named types to their fields.** `order: Order` alone is useless for
  tracing shape — resolve `Order` to its actual structure. Nest one level deep;
  for a field that's itself a complex type, expand it inline **or** point to it:
  `items: LineItem[] → see [[buildLineItem]]`.
- **Return shape too** — add a `Returns —` line in the same expanded form.
- **Dynamically-typed code** (Python/JS without annotations): infer the shape
  from how the parameter is constructed and used, and mark it `(inferred)`.
- Don't re-expand a type you've already expanded in a nearby note — link to it.

<EITHER the code, trimmed to the relevant lines — when it's straightforward:
```lang
...
````

OR a plain-language explanation — when it's a complex algorithm.>

**Example** — `input` → `output`. Use **concrete, fully-populated values** that
show the shape (real-looking objects, not `{...}`). Omit only if the function
genuinely can't have a meaningful one, e.g. pure side-effect wiring.

**Calls** — [[methodA]], [[methodB]] ← the methods this one invokes; recurse into each.

```

Then repeat for each method linked under **Calls**. This walks the call graph
depth-first down the spine.

### 5. Know when to stop a branch

Don't expand a branch when it's:
- a **trivial utility** — a formatter, a getter, a thin wrapper. Name it in the
  caller's one-liner and don't give it a file.
- **off the spine** — an error path, an admin endpoint, a rarely-hit branch.
  Note it exists, don't follow it.
- **a boundary you've already named** — the DB call, the HTTP client. State
  what crosses the boundary, don't map the library behind it.

Better to map the spine to the bottom than every branch halfway. When a branch
is deep enough that the reader has the model, stop and say so.

## Wikilinks

Use `[[methodName]]` (Obsidian-style). Links resolve by filename, so keep
`functions/*.md` names unique. If two methods share a name, disambiguate:
`[[handleFoo (parser)]]`. A wikilink to a file you decided not to create (a
skipped utility) is fine — it just won't resolve, which signals "not expanded on
purpose".

## Scope

Timebox it. 70% coverage of the spine beats 100% of everything — the reader
fills the rest in once they're working in the code. If the codebase is large,
map the one main flow well and list the other entry points in `overview.md` for
a later pass.
```
