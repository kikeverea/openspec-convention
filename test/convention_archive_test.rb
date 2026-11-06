# frozen_string_literal: true

# Tests `bin/convention archive` against a throwaway project, with a stand-in `openspec` that
# moves the change the way `openspec archive` does. Run: ruby test/convention_archive_test.rb
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

class ConventionArchiveTest < Minitest::Test
  SCRIPT = File.expand_path("../modules/core/bin/convention", __dir__)

  def setup
    @dir = Dir.mktmpdir
    write "bin/openspec", <<~SH
      #!/bin/sh
      if [ "$1" = archive ]; then
        mkdir -p openspec/changes/archive
        mv "openspec/changes/$2" "openspec/changes/archive/2026-11-06-$2"
      fi
      exit 0
    SH
    File.chmod(0o755, path("bin/openspec"))

    write "openspec/changes/split-tabs/proposal.md", "See [the spec](../../specs/table-service/spec.md) and [design](design.md).\n"
    write "openspec/changes/split-tabs/design.md", "Design.\n"
    write "openspec/changes/split-tabs/specs/table-service/spec.md", "Delta.\n"
    write "openspec/changes/split-tabs/diagrams/data-model.mmd", "%% model\n"
    write "openspec/changes/split-tabs/diagrams/split-flow.mmd", "%% flow\n"
    write "openspec/changes/split-tabs/diagrams/tab-lifecycle.mmd", "%% lifecycle\n"
    write "openspec/specs/table-service/diagrams/tab-lifecycle.mmd", "%% lifecycle\n"
    write "openspec/specs/table-service/spec.md", "Spec.\n"
    write "openspec/specs/table-service/implementation.md", <<~MD
      **Spec:** [`table-service`](../../changes/split-tabs/specs/table-service/spec.md) · **Changes:** [split-tabs](../../changes/split-tabs/), [design](../../changes/split-tabs/design.md#decisions)

      ## Limitations
      - **No separate payments within a table.** One tab per table.
    MD
    write "docs/backlog.md", <<~MD
      # Backlog

      ## Working on

      - [No separate payments within a table](../openspec/specs/table-service/implementation.md): [split-tabs](../openspec/changes/split-tabs/)
      - [A draft can outlive its table](#bugs): [split-tabs](../openspec/changes/split-tabs/)
      - [Kitchen display](#next): [kitchen-display](../openspec/changes/kitchen-display/)

      ## Next

      Nothing ordered yet.

      ## Bugs

      - **A draft can outlive its table** (ruled 2026-11-05: "discard them"). Details. [Table service](../openspec/specs/table-service/implementation.md).
      - **Deleting a record in use gives a 500.** Details.

      ## Cleanups

      None known.
    MD
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_archives_and_does_the_mechanical_steps
    output, status = archive("split-tabs")
    assert status.success?, output

    page = read("openspec/specs/table-service/implementation.md")
    assert_includes page, "[`table-service`](spec.md)"
    assert_includes page, "[split-tabs](../../changes/archive/2026-11-06-split-tabs/)"
    assert_includes page, "(../../changes/archive/2026-11-06-split-tabs/design.md#decisions)"

    proposal = read("openspec/changes/archive/2026-11-06-split-tabs/proposal.md")
    assert_includes proposal, "[the spec](../../../specs/table-service/spec.md)"
    assert_includes proposal, "[design](design.md)"

    backlog = read("docs/backlog.md")
    refute_includes backlog, "split-tabs"
    refute_includes backlog, "A draft can outlive its table"
    assert_includes backlog, "[Kitchen display](#next)"
    assert_includes backlog, "Deleting a record in use gives a 500"

    assert_includes output, %(Update or remove the limitation "No separate payments within a table")
    assert_includes output, "diagrams/split-flow.mmd has no copy"
    refute_includes output, "tab-lifecycle.mmd has no copy"
    refute_includes output, "data-model.mmd has no copy"
  end

  def test_notes_an_empty_working_on
    write "docs/backlog.md", <<~MD
      ## Working on

      - [No separate payments within a table](../openspec/specs/table-service/implementation.md): [split-tabs](../openspec/changes/split-tabs/)

      ## Next
    MD
    archive("split-tabs")
    assert_includes read("docs/backlog.md"), "## Working on\n\nNothing in progress.\n\n## Next"
  end

  def test_refuses_an_unknown_change
    output, status = archive("nope")
    refute status.success?
    assert_includes output, "No change at openspec/changes/nope."
  end

  private

  def archive(name)
    env = { "PATH" => "#{path("bin")}:#{ENV.fetch("PATH")}" }
    Open3.capture2e(env, "ruby", SCRIPT, "archive", name, chdir: @dir)
  end

  def path(relative) = File.join(@dir, relative)
  def read(relative) = File.read(path(relative))

  def write(relative, content)
    FileUtils.mkdir_p(File.dirname(path(relative)))
    File.write(path(relative), content)
  end
end
