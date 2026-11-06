# Shared convention

These are the rules every project shares: how work is planned in OpenSpec, how it's documented, and how it's committed. Each project's `CLAUDE.md` imports this file next to its own `AGENTS.md`. `AGENTS.md` describes the project and adds what's specific to it: the domain, the stack, what counts as operations, the terms, the examples. Where a project deliberately departs from a rule here, its `AGENTS.md` says so; otherwise this file applies.

## Scope of OpenSpec: software only

OpenSpec changes, specs and tasks describe **what the software does and how it's built**. Operations — hardware, servers, networks, accounts, deploys, production data steps, anything done by hand outside the code — never become specs, tasks or design decisions in a change. They live in the project's runbooks (`docs/operations/`) and `docs/architecture/`. Each project's `AGENTS.md` lists what counts as operations there.

**Development never waits on operations.** No task, requirement or "done" criterion may depend on a physical device, a site visit, production access, or a third-party service or account (paid or not) being set up or reachable: tests stub them. Verify software locally (tests, CI, throwaway environments); operations happen independently, from the runbooks.

## Everything in English

Code (identifiers, comments, test names, fixtures, factories), specs, docs and diagrams are written in English. The only other language is what the project's users see: UI copy and the documents the app prints or sends (`AGENTS.md` lists them). Screen wireframes (`*-screen.mmd`) show the real UI text. Everywhere else (specs, proposals, designs, tasks, feature pages, and flow, model and logic diagrams), describe things in English; when you need the exact on-screen label, quote it in single quotes, e.g. the save button ('Guardar'), so it reads as a label rather than prose. Never write untranslated words outside quotes, including sample data. Domain terms get English names, listed in `AGENTS.md`.

A note about the UI isn't UI text: even inside a wireframe, layout notes such as "(full width)" go in the English `%%` caption, never next to a label.

## Diagrams are files, never embedded in Markdown

Text lives in `.md` files; diagrams live in their own `.mmd` files (Mermaid), which the user opens directly (Obsidian renders them with the Mermaid View plugin). **Never put a Mermaid block inside a Markdown file.** A Markdown page refers to a diagram with a one-line link, e.g. `Diagram: [order flow](diagrams/order-flow.mmd)`.

Every diagram must render. Obsidian draws them with its own Mermaid-compatible renderer, Pele, not Mermaid, and `bin/check-diagrams` renders them with the same build (`vendor/pele/`). Run it on every diagram you write (`bin/check-diagrams openspec/changes/<change>`); CI runs it on all of them. Mistakes it catches that are easy to make: parentheses or brackets inside an unquoted flowchart label (quote the label), and a `;` inside a sequence diagram message (it ends the statement). Avoid `direction LR` and `note` blocks: they make diagrams too wide for the pane. Run locally, the script also warns when Obsidian ships a newer Pele than `vendor/pele/`; updating it is a change to the convention (see the last section).

Every relative link in the docs must resolve: `bin/check-links` checks `AGENTS.md` and every `.md` under `openspec/` and `docs/`, and CI runs it. An example link that isn't meant to resolve goes in a code span.

Where diagrams live: `openspec/specs/<capability>/diagrams/` (how the feature works today), `openspec/changes/<change>/diagrams/` (the change's preview, archived with it), `docs/architecture/` (cross-cutting).

## Visual preview in every change

The OpenSpec workflow (`openspec/schemas/spec-driven-visual`, the default in `openspec/config.yaml`) adds a **`diagrams`** step after `design` and before `tasks`: one diagram file per view in the change's `diagrams/` folder (data model, lifecycles, flows, logic, screen wireframes, file tree), each starting with a one-line `%%` caption and nothing else. It's the user's review surface for the change. Keep it consistent with the specs and design; if a diagram reveals a gap, fix the design or specs first. Data models are always `erDiagram` in the generated style, with crow's feet and new/changed/existing models marked, never `classDiagram`.

## The workflow

Propose (all artifacts) → apply, only when the user asks → archive. Proposing is planning only: no code until the user asks to apply. Ask before proposing when the answer changes behavior.

During apply, a decision the design didn't cover goes into `design.md` marked "decided during apply", and the affected specs, diagrams and tasks are fixed in the same pass, so the change stays consistent with what was built.

Archiving follows the `operations.archive.guidance` in `openspec/config.yaml` (diagrams, spec links, change links, the backlog lines and limitations the change settled, validation).

### Fixes: a change or a plain commit

A fix goes through OpenSpec when it changes what the spec says. Ask: **is the right behavior already written down?**

- **Outside the domain** (a typo, a margin, a misaligned icon, copy that says the same thing better): a plain commit. Specs say nothing about it.
- **Written down, and the code disagrees**: a plain commit. The fix brings the code back to what's already decided; nothing needs deciding.
- **Not written down** (a logic gap, an edge case nobody decided, a spec that's silent or wrong): a change. The fix is new behavior, so it needs a decision and a requirement (see "Specs say what was decided"). "Expected" means recorded: behavior that only seems obvious isn't written down. A bug ruled in the backlog (`ruled …`) whose spec is silent also goes through a change, so the ruling becomes a requirement instead of leaving with the bullet.

"Written down" means the main spec (`openspec/specs/<capability>/spec.md`): every archived change was merged into it, so it already holds the latest decision, and a later change that overrode an earlier one is already reflected there. Archived changes are history: a design decision counts only for what the spec doesn't reach (how something is built rather than what it does), and then the most recent archived change that decided it wins. When the answer isn't clear, ask the user.

A plain-commit fix still carries, in the same commit: a regression test that fails without the fix (not for cosmetic fixes), the bug's removal from the backlog's Bugs (and its line in Next), the feature page updated if what it says changed, and a message that names the bug by its title. It has no line in Working on: there's no change to link.

A fix that is a change is usually small: a proposal, a delta spec, tasks and the diagrams that apply, often just `files.mmd`. design.md only if a decision needs recording; no screen wireframe when the UI doesn't change.

## Exploration is not a change

Surveys, measurements and experiments happen in explore mode (`/opsx:explore`) and in scratch scripts under `tmp/` until the approach is settled; then it becomes a proposal. A measurement often exists before any change and serves several.

A design that rests on a measurement quotes the number, says which database it came from (development and production can differ: engine, data, query plans), and keeps the script that produced it: copy it into each change that quotes it, under `openspec/changes/<change>/measurements/`. The script's header names its inputs (the database, and any files outside git), so it can be re-run against development. Keep the scripts and the numbers, never their outputs: outputs can hold real data. CI never re-runs them.

## Specs say what was decided

A requirement states a behavior the user decided or confirmed, not merely what the code happens to do. Each requirement rests on one of: a ruling by the user, a test written in an OpenSpec change (it asserts a spec the user approved), or behavior the code states plainly (a validation and its message, a guard with its reason). Behavior whose intent is unclear is **asked**, never written as SHALL: it could be an accident or a bug. A bug found this way goes in the backlog under Bugs, not in the spec.

A spec written from existing code (documenting a feature that was built before OpenSpec) states only what passes this rule. Everything else goes in the backlog under To decide, to be asked. A test written before OpenSpec, or outside a change, shows what the code does, not what was decided: it's a reason to ask, never a basis on its own. Git tells which tests came from a change.

**Correcting a spec** goes through a change even when no code changes: the archived change records why a requirement left, and main specs only change at archive. An audit of several specs is one change, with a delta spec per capability. Each doubtful requirement is asked, and the answer sends it one of three ways: confirmed, it stays; rejected, it's a bug, in the backlog's Bugs; unanswered, it's removed from the spec and becomes a question under To decide. Behavior never drops out of the docs unrecorded.

## Documentation is part of the change

A task that changes behavior, architecture, data or operations is not done until its documentation is updated in the same change. Never leave docs for a later "documentation pass".

### Features (`openspec/specs/<capability>/implementation.md`)

Each app-level OpenSpec capability has one page, `implementation.md`, in the same folder as its spec, with its model pages under `models/`. `spec.md` says *what* the capability must do; `implementation.md` says *how it's built*: the solution one level above the code (models and how they relate, flows, rules, where each piece lives), precise enough to discuss and decide on without reading the code. OpenSpec only reads `spec.md` and ignores the other files. Sections:

1. **Purpose**: what it does for the people using it, in plain language.
2. **How it works**: the main flows in short text, each with a link to its diagram file in `diagrams/` (sequence, state or flowchart).
3. **Models**: a table linking to the feature's model pages (`models/<model>.md`), a link to the generated `diagrams/data-model.mmd`, and used models as one line each, linking to their owner's page.
4. **Business rules**: the non-obvious ones, with the why.
5. **Code map**: controllers, models, pages, jobs, scripts, tests (paths).
6. **Spec and history**: link to the OpenSpec spec and the changes that shaped it.
7. **Limitations**: what the feature deliberately doesn't do (see below). Always the last section.

A project may add sections (an API section, a code map per repo); its `AGENTS.md` says which. `docs/README.md` maps every capability to its page. Don't add `README.md` files to capability folders; the feature page is `implementation.md`.

**New feature page.** When a change adds an app-level capability, create `openspec/specs/<capability>/implementation.md` from this skeleton (the folder may exist before `spec.md` does: archiving the change adds it) and add a row for it in `docs/README.md`:

```markdown
# <Feature name>

**Status:** implemented | in progress · **Spec:** [`<capability>`](<path to spec.md>) · **Changes:** `<change-name>`, ...

## Purpose
## How it works
Diagram: [<flow name>](diagrams/<flow-name>.mmd)
## Models
| Model | What it is |
|---|---|
| [User](models/user.md) | ... |

## Data model
Diagram: [data model](diagrams/data-model.mmd) (generated from the models).

## Business rules
## Code map
## Limitations
```

**Changing an existing feature.** In the same change: update the flows, business rules, code map and limitations; append the change name to **Changes**; update the hand-written *Meaning and rules* of every model page you touched. `docs:check` only guards the generated parts. Keeping the hand-written parts true is your job.

### Limitations and the backlog

A feature page describes what's built, so it holds only what's true of the shipped code. **Limitations** are boundaries of the design: what the feature deliberately doesn't do, true until a change moves them. They live on the feature's page, in its last section. Everything else is work still to do, and lives in the **backlog** (`docs/backlog.md`, linked from `docs/README.md`): bugs, cleanups and questions about shipped behavior. A known bug doesn't make a feature less "implemented"; it means the backlog has work on it.

Each limitation is one bullet that starts with a short bold title:

```markdown
## Limitations
- **No separate payments within a table.** A table has one tab; moving items to another table is the workaround.
- **No nested merges.** A merged table can't be merged again; undo it first.
```

The backlog has five sections, in this order:

```markdown
# Backlog

## Working on
- [No separate payments within a table](../openspec/specs/table-service/implementation.md): [split-tabs](../openspec/changes/split-tabs/)

## Next
1. [Deleting a record in use gives a 500](#bugs)
2. **Kitchen display.** Orders shown on a screen in the kitchen instead of printed.

## Bugs
- **Deleting a record in use gives a 500.** Most admin controllers: [menu](../openspec/specs/menu/implementation.md), [printing](../openspec/specs/printing/implementation.md).
- **A draft can outlive its table** (ruled 2026-11-05: "a replaced table's drafts are discarded"). Drafts on a device that's never reopened stay in its storage. [Table service](../openspec/specs/table-service/implementation.md).

## Cleanups
- **Unused `legacy_code` column.** Nothing reads it since the import was retired. [Menu](../openspec/specs/menu/implementation.md).

## To decide
- **Can a merge be extended?** Today it has to be undone first. [Table service](../openspec/specs/table-service/implementation.md).
```

- **Working on** ties each change in progress to what it builds or fixes: one line per item, the item's link (as in Next) followed by the change, `: [<change>](../openspec/changes/<change>/)`. A change that addresses several items has a line for each; work with nothing to point to is written in full, as in Next. Starting a change adds its lines here, moving them out of Next if they were there; nothing has to be in Next first.
- **Next** is the order of what comes next, decided by the user. Each line is a link whose text is the title of what it orders: a limitation, pointing to its feature page, or a bug or cleanup, pointing to its section (`#bugs`, `#cleanups`). Work that has nothing to point to yet (a new capability) is written in full as a numbered bold title and description. Questions are never ordered: they're asked.
- **Bugs**: the feature does something wrong. **Cleanups**: dead code, a stale column, an outdated comment or note; users see nothing wrong and nothing is missing. **To decide**: shipped behavior whose intent isn't settled, typically found while documenting code built before OpenSpec; ask the user. Each is a bullet with a bold title, a description, and plain links to the feature pages it affects. A bug that contradicts an explicit ruling by the user says so after its title, quoting the ruling with its date or linking where it was recorded: `(ruled 2026-11-05: "…")` or `(ruled: [design decision 4](…/design.md))`.
- **Questions about work not built yet** aren't backlog items: they belong to the change that builds it, as its proposal's or design's Open Questions. An answered question leaves To decide: it becomes a requirement, a limitation, a bug, or nothing.
- **Titles** are short and stable: they're how the lines in Working on and Next find their item, and `bin/check-links` checks that every one still resolves. Renaming a limitation, bug or cleanup means updating its line in the same change.
- **Planning lives only in the backlog.** Limitations, bugs and cleanups are plain facts with no state: being in Next means planned, being in Working on means a change is building it. An abandoned change removes its Working on lines, or moves them back to Next if the work is still wanted.
- **Archive.** The change removes its Working on lines when it's archived, not before. It updates or removes the limitation it moved (it's no longer true: ordinary documentation), and removes the bugs and cleanups it fixed. A Working on line the archive forgot still links to `changes/<change>/`, which no longer exists, so `bin/check-links` flags it.
- **One description.** A limitation lives on the page of the feature it bounds. When it spans features, it lives on the one it mainly bounds; other pages don't repeat it. Bugs, cleanups and questions are described only in the backlog, and link to every page they affect.
- **Not backlog items.** Steps owed on production (a data fix, a password to set) are operations: they go in a runbook.

**Spec and change links.** The feature page links to `spec.md` in its own folder. While a change that creates the capability is in progress, link to the delta spec inside `openspec/changes/<change>/specs/` instead, and switch to `spec.md` when the change is archived. **Changes** link to `../../changes/<change>/` while the change is in progress and to `../../changes/archive/<date>-<change>/` once it's archived.

**Model pages and ownership.** Every ActiveRecord model is owned by exactly one feature (the one that defines its lifecycle) and has its page at `openspec/specs/<feature>/models/<model>.md` (snake_case, e.g. `models/print_job.md`). Single-table subclasses have no page of their own: the base class's page lists them, and their meaning goes in its *Meaning and rules*.

```markdown
# User

**Feature:** [staff](../implementation.md) · **Status:** implemented

One or two sentences: what this model is for the people using the app.

## Summary
<!-- BEGIN generated: model User -->
<!-- END generated: model User -->

## Meaning and rules
- hand-written: what attributes mean when the name isn't enough, invariants, why
```

A feature that only uses a model writes one line in its `implementation.md`, e.g. `[**User**](../staff/models/user.md) (owned by staff): every order records who placed it`.

**Every mention of a model links to its page**, in hand-written text and in generated summaries alike (e.g. ``[`Order#total`](models/order.md)``), except a model page mentioning itself. The generator links attributes, associations and validations to the owning feature's page; links in hand-written text are your job.

**What the generator writes.** The format of generated docs is a convention the user chose; keep it, and change it only in the generator (`lib/model_docs/summary.rb`, `lib/model_docs/er_diagram.rb`, which belong to the convention) with tests in the project's `test/lib/model_docs_test.rb`, never by hand-editing output:

- **Model summary**, as `###` sub-sections with a blank line around every table and list (so Markdown renders them):
  - *Attributes*: a table (attribute, type, null, default, notes) sorted by name as in `db/schema.rb`, then "Also: `id`, `created_at`, `updated_at`". Foreign keys say `→ [Model](link)`.
  - *Subclasses*: only on a base class with single-table subclasses.
  - *Associations*: a list, one association per line, reading as a sentence: `- belongs_to [Table](table.md)`. When the name differs from the model, add it: ``- belongs_to [User](…/user.md) as `opened_by` ``. Options follow in parentheses (`dependent`, `through`, `optional`, `inverse_of`, `polymorphic`); `class_name` is left out because the link shows the model.
  - *Enums* and *Validations*: tables. Validations on an association link to that model.
  - *Scopes*: a list. An empty section says "None."
- **Data-model diagrams** (`erDiagram`): a feature's own models with their attributes; models it only uses from another feature appear as plain boxes with no attributes, labelled with the owner underneath in small type: `USER["USER<br/><small>(staff)</small>"]`.

**Generated docs.** Never edit text between `BEGIN/END generated` markers by hand. After any change to a migration, association, validation, enum or scope, run:

```sh
bin/rails docs:models   # rewrites model summaries, each feature's diagrams/data-model.mmd and docs/architecture/data-model.mmd
```

`bin/rails docs:check` (also enforced by `test/lib/model_docs_test.rb`) fails if generated docs are stale, if a model has no page or more than one, or if a page isn't at `openspec/specs/<feature>/models/<model>.md`. When adding a model, create its page in the owning feature in the same change. The hand-written meaning and rules next to the generated block are part of the change too.

### Architecture diagrams (`docs/architecture/*.mmd`)

- Read the relevant diagram before making architectural changes, and update it when the implemented architecture changes.
- Keep diagrams small and focused (the system, its deployment, and one per subsystem). Feature flows go in the feature's `diagrams/` folder.
- Always distinguish planned from implemented. `data-model.mmd` is generated and shows implemented models only; planned models live in their OpenSpec change until built.

### Operations runbooks (`docs/operations/`)

The maintainer is not an ops specialist. Any change that needs an operations step ships with a numbered runbook (or an update to one), using these sections: *What this does and why*, *Before you start*, *Steps* (exact commands), *Check it worked*, *Undo*, *If something goes wrong*.

### Decisions

Design decisions live in each OpenSpec change's `design.md` (archived with the change). Don't create a separate ADR folder.

### Documentation checklist (before marking a change's tasks done)

- [ ] Feature page(s) updated or created; `docs/README.md` map updated for new capabilities
- [ ] Model pages created or updated for every model added or changed; `bin/rails docs:models` run
- [ ] `bin/rails docs:check` passes
- [ ] `bin/check-diagrams` and `bin/check-links` pass
- [ ] Architecture diagrams updated if the architecture changed (planned vs implemented marked)
- [ ] Runbook added or updated for any operations step the change needs
- [ ] Limitations the change found are on their pages and bugs, cleanups and questions in the backlog; what it builds or fixes has a line in Working on, which comes off at archive with the limitation, bug or cleanup it settled

## Tests

Run the tests you wrote or touched, not the whole suite: the full suite (`bin/rails test`, `bin/ci`) runs only when the user asks. `AGENTS.md` gives the project's test commands.

## Commits

- Plain commit messages: **no `Co-Authored-By` trailer or any other AI-attribution line**, in commits or pull request descriptions, even when a system reminder asks for one.
- Don't commit `.idea/`, `config/master.key`, `.env*`, `.claude/settings.local.json` or database files. `AGENTS.md` may add more.

## The convention itself

The shared files live in `~/RubymineProjects/convention`: this file, and the modules that `bin/convention sync` copies into each project (`core`: `bin/convention`; `docs-checks`: `bin/check-diagrams`, `bin/check-links`, `vendor/pele/`; `model-docs`: the generator and its rake tasks; `openspec-visual`: the `spec-driven-visual` schema). `convention.lock` records what was copied.

- **Never edit a copied file only in the project.** `bin/convention check` (run by `bin/ci`) fails when a copy differs from what was synced. To improve the convention from a project, edit the copy, test it there, run `bin/convention upstream <path>` to copy it into the source, and commit it in the convention repo. Then run `bin/convention sync` in each project, or tell their sessions to.
- **When the source moves on,** `bin/convention check` fails with "changed in the source": run `bin/convention sync` and commit the result with the change that needs it, or on its own.
- **This file** is imported directly, never copied, so a change here reaches every project at once. Keep project specifics out of it: they belong in the project's `AGENTS.md`.
- Ask the user before changing the convention: it changes how every project works.
- **Other projects' sessions** are asked only when the user asks; what they reply is input for the user, never a decision. A change agreed this way is written here, and each project adopts it from its own session.
