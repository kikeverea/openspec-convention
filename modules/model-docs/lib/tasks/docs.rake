namespace :docs do
  desc "Regenerate model summaries and the data-model diagrams"
  task models: :environment do
    generator = ModelDocs::Generator.new
    generator.write!
    puts "Generated docs are up to date."
    if generator.problems.any?
      warn generator.problems.map { |problem| "  - #{problem}" }.join("\n")
      abort "Model documentation has ownership problems (see AGENTS.md, \"Features\")."
    end
  end

  desc "Fail if generated docs are stale or a model has no (or more than one) owning feature"
  task check: :environment do
    generator = ModelDocs::Generator.new
    errors = generator.problems + generator.stale_files.map { |path| "#{path} is out of date: run bin/rails docs:models" }
    abort "Documentation check failed:\n#{errors.map { |error| "  - #{error}" }.join("\n")}" if errors.any?
    puts "Documentation check passed."
  end
end
