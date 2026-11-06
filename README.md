# Convention

The planning and documentation convention shared by the Rails projects (POS, garages, kik-balanga): OpenSpec with a visual preview step, a feature page per capability, generated model docs, diagrams as Mermaid files checked with Obsidian's renderer, and links that must resolve.

## What's here

| Path | What it is | How a project gets it |
|---|---|---|
| `CONVENTION.md` | The shared rules for agents | Imported by the project's `CLAUDE.md`, never copied |
| `modules/core/` | `bin/convention`: sync and drift check | Copied by `bin/convention sync` (always) |
| `modules/docs-checks/` | `bin/check-diagrams`, `bin/check-links`, `vendor/pele/` (the Pele build Obsidian uses) | Copied |
| `modules/model-docs/` | `lib/model_docs*.rb`, `lib/tasks/docs.rake` (`docs:models`, `docs:check`) | Copied |
| `modules/openspec-visual/` | The `spec-driven-visual` OpenSpec schema and its templates | Copied |

Each module mirrors the project's layout: `modules/docs-checks/bin/check-links` lands at `bin/check-links`.

Not part of the convention, and owned by each project: `AGENTS.md`, `openspec/config.yaml` (its rules and archive guidance name project specifics), `test/lib/model_docs_test.rb` (it tests against the project's own models), and the OpenSpec skills and commands that `openspec update` generates.

## Adopting it in a project

From the project's root:

```sh
~/RubymineProjects/convention/bin/convention sync core docs-checks model-docs openspec-visual
```

If the project already has its own copies, sync lists the ones that differ and stops. Move whatever is worth keeping into the source first, then rerun with `FORCE=1`. Then:

1. Make `CLAUDE.md` import both files:
   ```markdown
   @AGENTS.md
   @~/RubymineProjects/convention/CONVENTION.md
   ```
   Claude Code asks once to allow an import from outside the project.
2. Trim `AGENTS.md` to what's specific to the project: what it is, the stack and commands, what counts as operations, which surfaces are in the users' language and the English names of domain terms, extra feature page sections, extra files never to commit, and any rule it deliberately changes.
3. Run `bin/convention check` from `bin/ci` (or whatever the project runs before pushing). It passes where the source isn't checked out, such as GitHub CI.
4. Commit `convention.lock` and the copied files.

The scripts need Ruby (`bin/convention`) and Node 22.12 or newer (`bin/check-diagrams`, `bin/check-links`; they use ES modules and no packages).

## Changing it

Ask the user first: a change here changes every project.

1. Edit the copy in the project you're working in and test it there.
2. `bin/convention upstream <path>` copies it into `modules/`. Commit it here.
3. `bin/convention sync` in that project, then in the others (or ask their sessions to). Until they do, their `bin/convention check` fails with "changed in the source".

For `CONVENTION.md`, edit it here directly: every project reads it at once.

When Obsidian updates Pele, `bin/check-diagrams` warns. Copy Obsidian's `lib/pele.min.js` to `modules/docs-checks/vendor/pele/pele-<version>.min.js`, delete the old one, run `bin/check-diagrams` in each project, and sync.
