// Run with: node --test test/*.test.mjs
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { test } from "node:test"
import { fileURLToPath } from "node:url"

const script = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../modules/docs-checks/bin/check-links")

// A throwaway project: { "relative/path.md": "content" }, checked as a whole.
function check(files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "check-links-"))
  for (const [ file, content ] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true })
    fs.writeFileSync(path.join(dir, file), content)
  }
  const run = spawnSync(process.execPath, [ script, "openspec", "docs" ], { cwd: dir, encoding: "utf8" })
  return { ok: run.status === 0, output: run.stdout + run.stderr }
}

const page = (items, extra = "") => `# Tables\n\n## Business rules\n- **A merge is not a delete.** Rule.\n${extra}\n## Limitations, bugs and open questions\n${items}\n`
const TABLES = "openspec/specs/tables/implementation.md"
const PRINTING = "openspec/specs/printing/implementation.md"

test("a backlog line finds its item by title", () => {
  const result = check({
    [TABLES]: page("- **Limitation:** **No separate payments within a table** (planned). One tab per table.\n"),
    "docs/backlog.md": "# Backlog\n\n1. [No separate payments within a table](../openspec/specs/tables/implementation.md)\n"
  })
  assert.ok(result.ok, result.output)
})

test("a backlog line whose item was renamed or removed fails", () => {
  const result = check({
    [TABLES]: page("- **Limitation:** **Split bills** (planned). One tab per table.\n"),
    "docs/backlog.md": "1. [No separate payments within a table](../openspec/specs/tables/implementation.md)\n"
  })
  assert.ok(!result.ok)
  assert.match(result.output, /no item titled "No separate payments within a table"/)
})

test("a title is only looked for in the items section, not in bold lead-ins elsewhere", () => {
  const result = check({
    [TABLES]: page("- **Bug:** **Something else.** Text.\n"),
    "docs/backlog.md": "1. [A merge is not a delete](../openspec/specs/tables/implementation.md)\n"
  })
  assert.ok(!result.ok)
})

test("titles match with code spans and without a trailing period", () => {
  const result = check({
    [TABLES]: page("- **Bug:** **`Tab#close` keeps drafts.** Text.\n"),
    "docs/backlog.md": "1. [`Tab#close` keeps drafts](../openspec/specs/tables/implementation.md)\n"
  })
  assert.ok(result.ok, result.output)
})

test("a pointer needs an item with its title where it points", () => {
  const items = "- **Bug:** **Deleting a record in use gives a 500.** Most controllers.\n"
  const good = check({
    [TABLES]: page("- **Bug:** **Deleting a record in use gives a 500**: see [backlog](../../../docs/backlog.md).\n"),
    [PRINTING]: page("- **Bug:** **Deleting a record in use gives a 500**: see [backlog](../../../docs/backlog.md).\n"),
    "docs/backlog.md": `1. ${items.slice(2)}`
  })
  assert.ok(good.ok, good.output)

  const stale = check({
    [TABLES]: page("- **Bug:** **Deleting a record in use gives a 500**: see [printing](../printing/implementation.md).\n"),
    [PRINTING]: page("- **Bug:** **Deletes give a 500.** Text.\n")
  })
  assert.ok(!stale.ok)
  assert.match(stale.output, /the pointer "Deleting a record in use gives a 500" has no item/)
})

test("links to changes and to design decisions inside an item aren't pointers", () => {
  const result = check({
    [TABLES]: page("- **Bug:** **Drafts outlive tables** (proposed: [fix-drafts](../../changes/fix-drafts/)). (ruled: [decision 4](../../changes/fix-drafts/design.md)).\n"),
    "openspec/changes/fix-drafts/design.md": "# Design\n"
  })
  assert.ok(result.ok, result.output)
})

test("a proposed item whose change was archived is flagged by the broken link", () => {
  const result = check({
    [TABLES]: page("- **Bug:** **Drafts outlive tables** (proposed: [fix-drafts](../../changes/fix-drafts/)).\n")
  })
  assert.ok(!result.ok)
  assert.match(result.output, /changes\/fix-drafts\//)
})
