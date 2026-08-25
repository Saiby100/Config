---
name: compromise
description: Explain what a piece of code does using concrete input/output examples, name what is driving most of its complexity, then sketch a concrete solution — an example input/output, the code, and the folder/function-distribution implications — so the user can decide whether the complexity is worth keeping. Use when invoked on a file, a file:line range, a function, or a pasted snippet.
---

# compromise

Explain the code, then price its complexity. The user decides whether to pay.

This skill **explains, recommends, and sketches a solution. It never edits.**
The solution is _shown_ — a worked example plus a code sketch in the chat —
never written into the file, even when the verdict is that the complexity
isn't worth it. No refactoring, no "while I was here". If the user wants the
change applied, they will ask in a separate turn.

## What you're given

The argument is one of: a file path, `path:12-48`, a function or symbol name, or
a snippet pasted straight into the prompt.

- **A path with no range** — cover the whole file if it's one coherent unit.
  If it's large and mixed, say which part you're covering and why (the most
  complex part, unless the prompt points elsewhere).
- **Nothing at all** — ask which file or snippet, in one line. Don't guess from
  recent context.

## Steps

### 1. Read enough to be right

Read the target. Then read only what you need to explain it truthfully:

- the callers, to know what real inputs look like
- the functions it calls, to know what it gets back
- the git history of the target lines (`git log -L`, `git blame`) when a piece
  of code looks arbitrary — commit messages usually name the bug that put it
  there, which is the difference between "this is load-bearing" and "this is
  scar tissue"

Stop when more reading won't change the explanation. Don't map the whole repo.

### 2. Verify the examples, don't imagine them

Every example input/output pair must be one you actually checked, by whichever
of these is cheapest:

- run the code on your input (a scratch script, a REPL, the project's own test
  runner)
- run the underlying tool directly, if the code is mostly a wrapper (a shell
  pipeline, a query, a regex)
- read an existing test that already pins the behaviour, and cite it

If you can't run it, trace it by hand — and **say so**, marking that pair as
traced rather than executed. Never present a guessed output as a real one. A
wrong example is worse than no example: the user will make the keep-or-drop call
on the strength of it.

### 3. Report

Use these five sections, in this order.

**What it does** — two or three sentences, plain language. What goes in, what
comes out, what it's for. No implementation detail yet.

**Walkthrough** — the main path, driven by concrete values. Real filenames, real
strings, real numbers from this codebase, never `foo`/`bar`. Show the shape:

```
input:   "src *.ts :: Button"
         ↓ split on " :: "
scope:   "src *.ts"          query: "Button"
         ↓ parse_scope
dirs:    { "src" }           globs: { "*.ts" }
output:  rg --files --glob '*.ts' src
```

Then 1–3 more examples, each chosen to exercise a branch that _only exists_
because of the complexity you're about to price. These are the payload: they
show the user what they'd lose. Cite the lines each one goes through.

**What's driving the complexity** — a ranked list, most expensive first. For
each one:

- the mechanism, named in plain words, with `file:line`
- roughly how much of the code it accounts for — lines, branches, or extra
  functions
- what it buys: the case that breaks without it (an input from your examples)
- what the code collapses to if dropped — sketch the simpler version in a few
  lines, so the saving is visible and not just asserted

Separate the two kinds as you go, because they get judged differently:

- **essential** — the problem itself is this hard. The complexity moved
  somewhere else if you delete it; it doesn't disappear.
- **incidental** — a choice, a workaround, a library's shape, an old bug's
  scar. This is the stuff that's actually up for negotiation.

**The call** — your recommendation, in a few lines: what you'd keep, what you'd
drop, and the one thing you'd do first. Commit to a view. If the honest answer
is "keep all of it, the problem is just hard", say that plainly.

**The solution** — the shape you'd move to, shown concretely so the user can
picture it before agreeing to it. Skip this section only when the verdict is
keep-all — then say so in one line ("the current shape _is_ the solution; the
problem is just this hard") and stop. Otherwise show three things:

- **Example** — one input run through the _proposed_ code, with its output, in
  the same arrow style as the walkthrough. Use an input that exercised the
  complexity you're dropping, so the user can see the new shape still handles
  it (or see exactly which edge case it gives up). Mark it **traced** unless
  you actually ran the sketch — you usually can't, since it isn't written yet.

  ```
  input:   "src *.ts :: Button"
           ↓ one split, no scope parser
  output:  rg --files -g '*.ts' src   # same command, ~40 fewer lines
  ```

- **The code** — the sketch itself, the few lines the target collapses to.
  Trim to what changed; `...` for the parts that stay. Enough that the user
  reads it and knows it's real, not so much that it's the actual patch.

- **Structure** — the folder and function layout the change implies, because
  that is how the user reasons about code. Name it plainly:
  - which **files** appear, merge, move, or disappear (`a/parse_scope.ts` folds
    into `a/run.ts`; `helpers/` empties out)
  - how the **functions redistribute** — what merges into one, what splits out,
    what stops being its own function and becomes three inline lines, what
    changes signature. Say where each lands (`file:line` for what exists today).
  - if the shape barely moves — one function, no new files — say that outright
    so the user isn't hunting for a reorg that isn't there.

Then stop and let the user decide. Don't ask "want me to refactor it?" — they'll
say so if they do.

## Rules

- Plain language. If a sentence needs re-reading, rewrite it.
- Every claim about the code carries `file:line`.
- Distinguish **verified** (ran it, read it) from **inferred** (pattern-matched,
  assumed from a name). Never dress one as the other.
- Complexity you don't understand yet is not complexity you can price. If a
  chunk resists explanation, say which chunk and what you'd need to read to
  settle it, rather than hand-waving past it.
- Don't grade the author. "This is here because X breaks otherwise" beats "this
  is over-engineered" — the cost/benefit is the argument, not the adjective.
- Length follows the code. A 30-line function gets a short answer.
