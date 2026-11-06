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

const page = (limitations) => `# Tables\n\n## Business rules\n- **A merge is not a delete.** Rule.\n\n## Limitations\n${limitations}\n`
const backlog = (next, rest = "") => `# Backlog\n\n## Next\n${next}\n## Bugs\n${rest}\n## Cleanups\n\n## To decide\n`
const TABLES = "openspec/specs/tables/implementation.md"
const BACKLOG = "docs/backlog.md"
const TABLES_LINK = "../openspec/specs/tables/implementation.md"

test("a line in Next finds its limitation by title", () => {
  const result = check({
    [TABLES]: page("- **No separate payments within a table** (planned). One tab per table.\n"),
    [BACKLOG]: backlog(`1. [No separate payments within a table](${TABLES_LINK})\n`)
  })
  assert.ok(result.ok, result.output)
})

test("a line in Next whose limitation was renamed or removed fails", () => {
  const result = check({
    [TABLES]: page("- **Split bills** (planned). One tab per table.\n"),
    [BACKLOG]: backlog(`1. [No separate payments within a table](${TABLES_LINK})\n`)
  })
  assert.ok(!result.ok)
  assert.match(result.output, /no limitation titled "No separate payments within a table"/)
})

test("a title is only looked for under Limitations, not in bold lead-ins elsewhere", () => {
  const result = check({
    [TABLES]: page("- **Something else.** Text.\n"),
    [BACKLOG]: backlog(`1. [A merge is not a delete](${TABLES_LINK})\n`)
  })
  assert.ok(!result.ok)
})

test("a line in Next finds a bug in the backlog's own section", () => {
  const good = check({
    [TABLES]: page(""),
    [BACKLOG]: backlog("1. [Deleting a record in use gives a 500](#bugs)\n", `- **Deleting a record in use gives a 500** (planned). [Tables](${TABLES_LINK}).\n`)
  })
  assert.ok(good.ok, good.output)

  const stale = check({ [BACKLOG]: backlog("1. [Deleting a record in use gives a 500](#bugs)\n", "- **Deletes give a 500.** Text.\n") })
  assert.ok(!stale.ok)
  assert.match(stale.output, /no bullet titled "Deleting a record in use gives a 500" under "Bugs"/)

  const nowhere = check({ [BACKLOG]: backlog("1. [Deleting a record in use gives a 500](#bug)\n") })
  assert.ok(!nowhere.ok)
  assert.match(nowhere.output, /#bug, a section the backlog doesn't have/)
})

test("titles match with code spans and without a trailing period", () => {
  const result = check({
    [BACKLOG]: backlog("1. [`Tab#close` keeps drafts](#bugs)\n", "- **`Tab#close` keeps drafts.** Text.\n")
  })
  assert.ok(result.ok, result.output)
})

test("new work written in full in Next needs nothing to point to", () => {
  const result = check({ [BACKLOG]: backlog("1. **Kitchen display.** Orders on a screen.\n") })
  assert.ok(result.ok, result.output)
})

test("bold titles inside code blocks are not limitations", () => {
  const result = check({
    [TABLES]: page("```markdown\n- **Split bills.** Example.\n```\n"),
    [BACKLOG]: backlog(`1. [Split bills](${TABLES_LINK})\n`)
  })
  assert.ok(!result.ok)
})

test("a proposed limitation whose change was archived is flagged by the broken link", () => {
  const result = check({
    [TABLES]: page("- **Drafts outlive tables** (proposed: [fix-drafts](../../changes/fix-drafts/)).\n")
  })
  assert.ok(!result.ok)
  assert.match(result.output, /changes\/fix-drafts\//)
})
