# Convention

The planning and documentation convention shared by the Rails projects (POS, garages, kik-balanga): OpenSpec with a visual preview step, a feature page per capability, generated model docs, diagrams as Mermaid files checked with Obsidian's renderer, and links that must resolve.

## What's here

| Path | What it is | How a project gets it |
|---|---|---|
| `CONVENTION.md` | The shared rules for agents | Imported by every project's `CLAUDE.md`, never copied |
| `modules/core/` | `bin/convention`: sync, drift check, and `archive` (an OpenSpec archive plus its mechanical follow-up) | Copied by `bin/convention sync` (always) |
| `modules/docs-checks/` | `bin/check-diagrams`, `bin/check-links`, `vendor/pele/` (the Pele build Obsidian uses) | Copied |
| `modules/model-docs/` | `lib/model_docs*.rb`, `lib/tasks/docs.rake` (`docs:models`, `docs:check`) | Copied |
| `modules/openspec-visual/` | The `spec-driven-visual` OpenSpec schema and its templates | Copied |

Each module mirrors the project's layout: `modules/docs-checks/bin/check-links` lands at `bin/check-links`.

Not part of the convention, and owned by each project: `AGENTS.md`, `openspec/config.yaml` (its rules name project specifics; the shared archive steps are `bin/convention archive`), `test/lib/model_docs_test.rb` (it tests against the project's own models), and the OpenSpec skills and commands that `openspec update` generates.

## Adopting it in a project

From the project's root:

```sh
~/convention/bin/convention sync core docs-checks model-docs openspec-visual
```

If the project already has its own copies, sync lists the ones that differ and stops. Move whatever is worth keeping into the source first, then rerun with `FORCE=1`. Then:

1. Make `CLAUDE.md` import both files. The convention lives at `~/convention` on every computer (clone it there; `CONVENTION_ROOT` overrides it for `bin/convention` only):
   ```markdown
   @AGENTS.md
   @~/convention/CONVENTION.md

   The second import is the shared convention. If its rules ("Shared convention") don't appear above, `~/convention` isn't on this computer: ask the user before doing any work.
   ```
   Claude Code asks once to allow an import from outside the project.
2. Trim `AGENTS.md` to what's specific to the project: what it is, the stack and commands, what counts as operations, which surfaces are in the users' language and the English names of domain terms, extra feature page sections, extra files never to commit, and any rule it deliberately changes.
3. Run `bin/convention check` from `bin/ci` (or whatever the project runs before pushing). It passes where the source isn't checked out, such as GitHub CI.
   Run `bin/check-diagrams` and `bin/check-links` in GitHub CI too, in a job with `actions/setup-node` set to Node 22.12 or newer: the runner's default Node may be older.
4. Commit `convention.lock` and the copied files.

The scripts need Ruby (`bin/convention`) and Node 22.12 or newer (`bin/check-diagrams`, `bin/check-links`; they use ES modules and no packages).

## Changing it

Ask the user first: a change here changes every project.

1. Edit the copy in the project you're working in and test it there.
2. `bin/convention upstream <path>` copies it into `modules/`. Commit it here.
3. `bin/convention sync` in that project, then in the others (or ask their sessions to). Until they do, their `bin/convention check` fails with "changed in the source".

For `CONVENTION.md`, edit it here directly: every project reads it at once. It's read in place, never copied, so keep project specifics out of it: they belong in each project's `AGENTS.md`. Agree it with the user, and with the other projects' sessions only when the user asks; then tell those sessions to adopt it.

The convention's own tests cover `bin/check-links` (`node --test test/*.test.mjs`) and `bin/convention archive` (`MT_NO_PLUGINS=1 ruby test/convention_archive_test.rb`). The generator is tested in each project (`test/lib/model_docs_test.rb`), against its own models; lint shared Ruby with a project's `bin/rubocop` before upstreaming.

When Obsidian updates Pele, `bin/check-diagrams` warns. Copy Obsidian's `lib/pele.min.js` to `modules/docs-checks/vendor/pele/pele-<version>.min.js`, delete the old one, run `bin/check-diagrams` in each project, and sync.

## Where each rule lives

The rules live where an agent needs them: always-on rules in `CONVENTION.md`, step rules in the OpenSpec schema (served by `openspec instructions` while writing that artifact), and mechanical rules in scripts. This index is for reading them all in one place; agents don't need it.

**`CONVENTION.md`** (every session):
- The user's explicit instruction beats the convention; quality beats the convention. Either way, say what you set aside.
- OpenSpec only when the user asks (explore, proposal, change); everything else is direct work. Propose → apply when asked → archive.
- Explorations happen in explore mode and `tmp/`.
- Software only; development never waits on operations or third-party accounts.
- Fixes are plain commits; errors, crashes, data loss and security holes are bugs by definition; "decided" means the main spec; what a fix commit carries.
- Specs say what was decided (details in the schema); specs are corrected when the user asks.
- Everything in English except what users see; labels in single quotes; domain terms in `AGENTS.md`.
- Where things live (the table); diagrams are `.mmd` files that render; links resolve.
- Documentation ships with the work: feature pages and their sections, changing a feature, model links, generated docs, architecture diagrams, runbooks.
- Limitations and the backlog: the four kinds, bullet format, Working on, Next, titles, one description.
- Tests you touched; plain commits; files never committed.
- Ask the user before changing the convention; other sessions only when the user asks.

**The schema** (`modules/openspec-visual/openspec/schemas/spec-driven-visual/schema.yaml`):
- *Proposal:* ask before guessing at behavior; a fix stays small; add the change's Working on lines; questions about new work stay in the change.
- *Specs:* what a requirement may rest on; tests from before OpenSpec; specs written from code; correcting specs.
- *Design:* decisions live here; name each model's owner; measurements.
- *Diagrams:* one file per view with a caption; which views; a small fix needs only `files.mmd`; no `direction LR` or `note`; layout notes in the caption; erDiagram only.
- *Tasks:* documentation in each group; the feature page and model page skeletons; the verification task and its checklist.
- *Apply:* "decided during apply"; archive with `bin/convention archive`.

**Scripts:**
- `bin/check-diagrams`: every diagram renders with Pele.
- `bin/check-links`: every relative link resolves; Working on and Next lines find their titles.
- `bin/rails docs:models` / `docs:check`: generated docs current and never hand-edited; one page per model at its path; the format changes only in the generator (its header says so).
- `bin/convention check`: copies stay in step; edits go upstream.
- `bin/convention archive <change>`: Working on lines and the bugs and cleanups they name come off; links follow the change to the archive (delta-spec links go to the main spec); links inside the change are rebased; the checks run; the limitations it moved and the diagrams not yet copied are listed for the agent.
