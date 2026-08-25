---
name: feature-review
description: Deep-review a large feature PR by first reconstructing the changed program flow into browsable notes (same shape as explore-codebase — overview, architecture walk, per-method files with shapes and examples), then reviewing on top with edge-case rigor, and writing findings bucketed by severity with an acceptance-criteria check. Use for big/multi-file feature PRs where a plain diff review isn't enough. For small PRs, use the resonance pr-review command instead.
---

# feature-review

Review a **big feature PR** the way it actually has to be done: understand the
change first, then judge it. A large PR won't fit in your head from the diff
alone, so you rebuild the changed flow as notes (reusing the `explore-codebase`
machinery), then layer a rigorous review on top.

This is the **review** counterpart to `explore-codebase`. The frames are
opposite on purpose:

- **explore** = happy path, ignore edge cases, build a mental model.
- **review** = the model is a means to an end; the edge cases, the callers, and
  the unhappy paths are the whole point.

Use this only for **large, multi-file feature PRs**. A small or single-purpose
PR should go through the resonance `pr-review` command — don't over-build.

## Where notes go

Same home and conventions as `explore-codebase`:

```
~/Developer/reader/Codebases/<project>/<feature>/
  overview.md          # what the PR does + the verdict
  architecture.md      # the CHANGED program flow, spine through the diff, wikilinks
  functions/<m>.md     # per changed/key method: shape, code-or-explanation, example, + ## Review
  review.md            # findings by severity + acceptance-criteria table
```

- `<project>` — kebab-case codebase name. `<feature>` — kebab-case name of the
  PR's feature.
- **If this feature was already explored** (the folder exists from
  `explore-codebase`), reuse those notes — don't rewrite them. Extend the
  program-flow notes to cover what the diff changed, and add the `## Review`
  sections and `review.md`.
- **All the note rules carry over from `explore-codebase`:** program-flow order,
  `[[wikilinks]]` between notes, **absolute** paths to the target code,
  shape-expanded params/returns, concrete input→output examples, verbatim
  well-formatted snippets, code-when-straightforward / prose-for-complex.

## The frame (diff-first — the reverse of exploration)

### 1. Context

Fetch the PR and its linked issues — this tells you what the change is _supposed_
to do, which is what you review against.

```bash
gh pr view $PR --json number,title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,url
gh pr view $PR --comments
gh pr diff $PR
```

Parse the body for linked issues (`#123`, `Fixes #123`, issue URLs). For each:

```bash
gh issue view <n> --json title,body,state
```

Pull out the **requirements** and **acceptance criteria** — you'll check the PR
against them at the end.

(Input can also be a branch/local diff: `git diff <base>...<head>`. Same flow,
skip the `gh` issue lookups if there's no PR.)

### 2. Read the whole diff first

Read the entire diff before writing anything. Get the shape of the change: which
files, which layers, what the feature adds. Don't start judging yet — you can't
review a line until you know what the change as a whole is doing.

### 3. Map the changed spine → notes

Reconstruct the **new feature's program flow** through the diff, as
`explore-codebase` notes. Walk it in execution order from the new entry point
(the new route, command, handler, job). One `functions/<m>.md` per method **on
the changed spine** — new methods, and existing methods the diff modifies.

This is the understanding pass. Keep it to the spine of the change; don't map
untouched code except where you must to judge a caller (see below).

### 4. Review each changed method — the rigor pass

For every method on the changed spine, add a `## Review` section to its note.
This is where you do what exploration deliberately skips:

- **Correctness on the unhappy paths** — empty input, null, timeout, partial
  failure, the second concurrent call. Trace them, don't assume them.
- **Callers (breadth pass)** — for any _existing_ function the diff changed,
  find **who else calls it** (`grep`) and check the new behaviour still
  satisfies them. This is the single most valuable check on a big PR and the one
  a diff-only review misses. Note each caller and whether it's safe.
- **Boundaries** — new DB queries (N+1? migration needed?), network calls
  (retries, timeouts?), filesystem, other services.
- **State & concurrency** — shared/mutable state, ordering assumptions, races.
- **Tests as spec** — read the PR's tests. What do their names claim, and what
  did they _not_ cover? Missing edge-case tests are a finding.
- **Consistency** — does it follow existing patterns? `grep`/read 1–2 reference
  implementations and cite them when the PR diverges. Don't force a comparison
  when the pattern is genuinely new — say it's new.
- **Security** — authz checks, input validation, injection, secrets, sensitive
  data.

Keep each point concrete and tied to a line. A `## Review` section with nothing
wrong should say so in one line, not invent problems.

### 5. Write `review.md` — findings by severity

````md
# Review — <feature> (PR #<n>)

> reviewed: <YYYY-MM-DD> · base: <baseRef> · head: <headRef> · <url>

**Verdict** — one sentence: what this PR does and whether it's mergeable.

## 🔴 Blockers (must fix before merge)

### <short title>

- **Where** — `/abs/path/to/file.ext:42-50` · see [[methodName]]
- **Problem** — what's wrong and why it blocks.
- **Fix** —
  ```lang
  <concrete corrected code or approach>
  ```
````

- **Pattern** — matches/breaks `/abs/path/to/reference.ext` (cite when relevant).

## 🟡 Suggestions (should consider)

- `/abs/path:line` — issue → suggested change. see [[methodName]]

## 🟢 Nits (optional)

- `/abs/path:line` — minor.

## Acceptance criteria

| Criterion (from #<issue>) | Status       |
| ------------------------- | ------------ |
| <criterion>               | ✅ / ⚠️ / ❌ |

## What's good

One or two lines. Acknowledge the solid parts.

````

Severity rules (from resonance): **Blockers** = broken behaviour, data loss,
security holes, unmet acceptance criteria. **Suggestions** = pattern breaks,
missing edge-case handling, clarity. **Nits** = style, naming, docs. Omit a
bucket entirely if empty. Every finding carries an absolute `file:line` and,
where it helps, a `[[wikilink]]` into the method note that explains the context.

### 6. Offer to post (optional, confirm first)

The notes are the deliverable. Posting to GitHub is opt-in. If the user wants
it, map the verdict to the action and confirm before running:

- Blockers exist → `--request-changes`
- Only suggestions/nits → `--comment`
- Clean → `--approve`

```bash
gh pr review $PR {--approve|--comment|--request-changes} --body "<summary from review.md>"
````

Never post without explicit confirmation.

## Scope & stopping

- Map and review the **changed spine** thoroughly; don't re-review untouched
  code beyond the caller check in step 4.
- Don't suggest changes outside the PR's scope — note them separately if they
  matter, but keep the review about this PR.
- Be concrete and constructive. Concrete fix over vague complaint; cite the
  reference pattern; acknowledge what's done well.
