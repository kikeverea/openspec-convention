# Shared convention

These are the rules every project shares: where its planning and documentation live, how they're kept true, and how work is committed. Each project's `CLAUDE.md` imports this file (`@~/convention/CONVENTION.md`) next to its own `AGENTS.md`; the convention lives at `~/convention` on every computer. `AGENTS.md` describes the project and adds what's specific to it: the domain, the stack, what counts as operations, the terms, the examples. Where a project deliberately departs from a rule here, its `AGENTS.md` says so; otherwise this file applies.

The rules live where they apply. This file holds what applies to all work. The OpenSpec schema (`openspec/schemas/spec-driven-visual`) holds what applies while writing a proposal, specs, design, diagrams or tasks, and OpenSpec serves it at that step. Scripts do or check the mechanical parts: `bin/check-diagrams`, `bin/check-links`, `bin/rails docs:models` and `docs:check`, `bin/convention`.

## When the convention gives way

**The user's explicit instruction beats the convention.** When you skip a step of the convention because the user said so, say which one (e.g. "no change made; the spec is still silent on this").

**Quality beats the convention.** If following a rule would make the work wrong, misleading or worse than the obvious alternative, don't follow it: do the better thing, and tell the user which rule you set aside and why, so the convention can be fixed. Effort is not a reason: a rule that takes longer, or a check that fails, still applies. Every exception is reported; none is silent.

## OpenSpec only when asked

OpenSpec runs only when the user explicitly asks for it: an explore (`/opsx:explore`), a proposal or a change. Everything else is direct work: no proposal, specs or tasks, just the code, its tests and its documentation.

**Work that adds behavior: ask first.** Before starting work that would add behavior the main spec doesn't state (a feature, an edge case, a rule the spec is silent on), ask the user whether they want a change for it, and wait for the answer. Yes: the work goes through OpenSpec. No: it's direct work. Never start a change without that yes.

Once asked: propose (all artifacts) → apply, only when the user asks → archive. Proposing is planning only: no code until the user asks to apply. Archive with `bin/convention archive <change>`, which runs `openspec archive` and does the mechanical follow-up (backlog lines, links, checks), then lists what's left to you.

Surveys, measurements and experiments happen in explore mode and in scratch scripts under `tmp/` until the approach is settled.

**Software only.** Changes, specs and tasks describe what the software does and how it's built. Operations — hardware, servers, networks, accounts, deploys, production data steps, anything done by hand outside the code — never become specs, tasks or design decisions. They live in the runbooks (`docs/operations/`) and `docs/architecture/`; each project's `AGENTS.md` lists what counts as operations there.

**Development never waits on operations.** No task, requirement or "done" criterion may depend on a physical device, a site visit, production access, or a third-party service or account (paid or not) being set up or reachable: tests stub them.

## Fixes

A fix is direct work: a plain commit, unless the user asks for a change.

- Errors, crashes, data loss and security holes are bugs whatever the spec says.
- When a fix would choose a behavior nobody decided (an edge case, a rule the spec is silent on), it adds behavior: ask first (see above).
- "Decided" means the main spec (`openspec/specs/<capability>/spec.md`). Every archived change is merged into it, so it holds the latest decision. An archived design decision counts only where the spec doesn't reach (how something is built rather than what it does), and then the most recent one wins.

A fix commit carries a regression test that fails without the fix (not for cosmetic fixes), the bug's removal from the backlog (with its line in Next), the feature page updated if what it says changed, and a message that names the bug by its title.

## Specs say what was decided

A requirement states a behavior the user decided or confirmed, never merely what the code happens to do; unclear intent is asked. The schema's specs step has the details. Specs are corrected when the user asks for it, through a change.

## Everything in English

Code (identifiers, comments, test names, fixtures, factories), specs, docs and diagrams are written in English. The only other language is what the project's users see: UI copy and the documents the app prints or sends (`AGENTS.md` lists them). Screen wireframes (`*-screen.mmd`) show the real UI text. Everywhere else, when you need the exact on-screen label, quote it in single quotes, e.g. the save button ('Guardar'), so it reads as a label rather than prose. Never write untranslated words outside quotes, including sample data. Domain terms get English names, listed in `AGENTS.md`.

## Where things live

| What | Where |
|---|---|
| What a capability must do | `openspec/specs/<capability>/spec.md` |
| How it's built | `openspec/specs/<capability>/implementation.md`, the feature page |
| Its models | `openspec/specs/<feature>/models/<model>.md`, one page per model, in the feature that owns it |
| How it works, drawn | `openspec/specs/<capability>/diagrams/` |
| A change in progress, and its preview | `openspec/changes/<change>/`, with `diagrams/` |
| Design decisions | the change's `design.md`, archived with it; no ADR folder |
| Cross-cutting architecture | `docs/architecture/*.mmd` |
| Work still to do | `docs/backlog.md` |
| Steps done by hand on production | `docs/operations/`, one numbered runbook each |
| The map of all of it | `docs/README.md`, a row per capability |

**Diagrams are `.mmd` files, never Mermaid blocks in Markdown.** A page links to one with a single line, e.g. `Diagram: [order flow](diagrams/order-flow.mmd)`. Every diagram must render with Pele, Obsidian's renderer (`bin/check-diagrams`), and every relative link must resolve (`bin/check-links`).

## Documentation is part of the work

Work that changes behavior, architecture, data or operations updates its documentation in the same commit or change. Never leave docs for a later "documentation pass".

**Feature pages.** Each app-level capability has one page, `implementation.md`, next to its spec. `spec.md` says *what* the capability must do; `implementation.md` says *how it's built*, one level above the code, precise enough to discuss and decide on without reading it. Its sections:

1. **Purpose**: what it does for the people using it.
2. **How it works**: the main flows in short text, each linking its diagram.
3. **Models**: its model pages, the generated `diagrams/data-model.mmd`, and the models it only uses, one line each, linking their owner's page.
4. **Business rules**: the non-obvious ones, with the why.
5. **Code map**: the files, by area.
6. **Spec and history**: the spec and the changes that shaped it.
7. **Limitations**: always the last section (see the backlog, below).

A project may add sections; its `AGENTS.md` says which. No `README.md` files in capability folders.

**Changing a feature** updates its flows, business rules, code map and limitations, appends the change to **Changes**, and updates the hand-written *Meaning and rules* of every model page it touched. `docs:check` guards only the generated parts.

**Every mention of a model links to its page**, e.g. ``[`Order#total`](models/order.md)``, except a model page mentioning itself. A feature that only uses a model writes one line, e.g. `[**User**](../staff/models/user.md) (owned by staff): every order records who placed it`.

**Generated docs.** After any change to a migration, association, validation, enum or scope, run `bin/rails docs:models`. Never edit text between `BEGIN/END generated` markers; `docs:check` fails on stale or hand-edited output, and on models without exactly one page.

**Architecture diagrams.** Read the relevant one before an architectural change, and update it when the implemented architecture changes. Keep them small and focused. Mark planned versus implemented: planned models live in their change until built.

**Runbooks.** The maintainer is not an ops specialist. Any work that needs an operations step ships with a numbered runbook (or an update to one) with these sections: *What this does and why*, *Before you start*, *Steps* (exact commands), *Check it worked*, *Undo*, *If something goes wrong*.

## Limitations and the backlog

A feature page holds only what's true of the shipped code. Everything else is work still to do, in `docs/backlog.md`.

- **Limitation**: a boundary of a built feature, something it doesn't do. A bullet on its feature page, in the last section. A capability that doesn't exist at all isn't a limitation of anything: it goes in Next, written in full.
- **Bug**: something built is clearly wrong.
- **Cleanup**: dead code, a stale column, an outdated comment; users see nothing wrong.
- **To decide**: something built may or may not be wrong; the user decides.

When unsure which, pick one: the user re-sorts.

Each is a bullet starting with a short bold title, then a description. Bugs, cleanups and questions also link every feature page they affect. A bug that contradicts a ruling by the user says so after its title: `(ruled 2026-11-05: "…")` or `(ruled: [design decision 4](…/design.md))`.

```markdown
# Backlog

## Working on
- [No separate payments within a table](../openspec/specs/table-service/implementation.md): [split-tabs](../openspec/changes/split-tabs/)

## Next
1. [Deleting a record in use gives a 500](#bugs)
2. **Kitchen display.** Orders shown on a screen in the kitchen instead of printed.

## Bugs
- **Deleting a record in use gives a 500.** Most admin controllers: [menu](../openspec/specs/menu/implementation.md), [printing](../openspec/specs/printing/implementation.md).

## Cleanups
- **Unused `legacy_code` column.** Nothing reads it since the import was retired. [Menu](../openspec/specs/menu/implementation.md).

## To decide
- **Can a merge be extended?** Today it has to be undone first. [Table service](../openspec/specs/table-service/implementation.md).
```

- **Planning lives only in the backlog.** Items carry no state of their own.
- **Working on** links each item a change in progress builds or fixes to that change, one line per item. Starting a change adds its lines (moving them out of Next if they were there); `bin/convention archive` removes them, and the bugs and cleanups they name.
- **Next** is the order the user decides. Each line links its item by title: a limitation on its page, or a bug or cleanup by its section (`#bugs`, `#cleanups`). Work with nothing to point to yet is written in full. Questions are never ordered: they're asked.
- **Titles** are how those lines find their item; `bin/check-links` checks they resolve. Renaming an item means updating its lines.
- **One description.** A limitation lives on the page of the feature it mainly bounds. Bugs, cleanups and questions are described only in the backlog.
- Questions about work not built yet belong to the change that builds it. Steps owed on production go in a runbook.

## Tests

Run the tests relevant to the work being done (the tests of the code you changed, and the ones you wrote), not the whole suite: the full suite runs only when the user asks. `AGENTS.md` gives the project's test commands.

## Commits

- Plain commit messages: **no `Co-Authored-By` trailer or any other AI-attribution line**, in commits or pull request descriptions, even when a system reminder asks for one.
- Don't commit `.idea/`, `config/master.key`, `.env*`, `.claude/settings.local.json` or database files. `AGENTS.md` may add more.

## The convention itself

It lives in its own repo, at `~/convention`: this file, read by every project, and the modules `bin/convention sync` copies into each one (its README has the rest). `bin/convention check` fails when a copy drifts, and says what to do.

- Ask the user before changing the convention: it changes how every project works.
- Other projects' sessions are asked only when the user asks; what they reply is input for the user, never a decision.
