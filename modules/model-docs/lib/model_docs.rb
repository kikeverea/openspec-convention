# Keeps the generated parts of the feature docs in sync with the models.
# See CONVENTION.md ("Features") and `bin/rails docs:models` / `docs:check`.
#
# A feature owns a model by having openspec/specs/<feature>/models/<model>.md
# (e.g. models/user.md) containing its marker block:
#
#   <!-- BEGIN generated: model User -->
#   <!-- END generated: model User -->
#
# Only the text between markers is rewritten; everything else is hand-written.
# Each feature that owns models also gets openspec/specs/<feature>/diagrams/
# data-model.mmd (its models plus stubs of borrowed ones), and the whole app
# gets docs/architecture/data-model.mmd.
#
# Single-table subclasses (Client < Contact) share their base class's table, so they have no
# page of their own: they are listed on the base class's page and links to them go there.
#
# A model whose table does not exist, or an association whose class cannot be loaded, is
# reported rather than crashing the run.
#
# PENDING_LIST (optional; no file means no list) names the models not documented yet, for a
# project adopting this with models already written. Each is exempt from "has no owning feature"
# until its page exists -- then it must leave the list. The list only shrinks.
module ModelDocs
  MODEL_DOCS_GLOB = "openspec/specs/*/models/*.md"
  GLOBAL_DIAGRAM = "docs/architecture/data-model.mmd"
  PENDING_LIST = "openspec/undocumented-models.txt"
  MODEL_BLOCK = /<!-- BEGIN generated: model ([\w:]+) -->\n.*?<!-- END generated: model \1 -->/m

  # The models that get a page: base classes only (an STI subclass shares its base's table and
  # page), and only those with a table.
  def self.application_models
    Rails.application.eager_load!
    ApplicationRecord.descendants.reject(&:abstract_class?)
                     .select { |model| model.base_class == model }
                     .select { |model| Object.const_defined?(model.name) rescue false } # not a test's throwaway class
                     .sort_by(&:name)
  end

  # The page file name for a model: "Presentation::Deck" -> "presentation_deck.md".
  def self.page_name(name) = "#{name.underscore.tr('/', '_')}.md"

  # An association's class, or nil when it cannot be loaded (a typo'd `through:`, a missing class).
  def self.klass_of(association)
    association.klass
  rescue NameError, NoMethodError, ArgumentError
    nil
  end

  class Generator
    def initialize(root: Rails.root, models: ModelDocs.application_models)
      Rails.application.eager_load! # so single-table subclasses are known
      @root = Pathname(root)
      @models = models.index_by(&:name)
    end

    # { "User" => ["openspec/specs/staff/models/user.md"], ... }
    def ownership
      # A plain hash, not one with a default block: looking up a model with no page (to link to it)
      # must not register it as owned.
      @ownership ||= documents.each_with_object({}) do |path, owners|
        path.read.scan(MODEL_BLOCK) { |(name)| (owners[name] ||= []) << relative(path) }
      end
    end

    def pending
      @pending ||= begin
        file = @root.join(PENDING_LIST)
        file.exist? ? file.readlines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") } : []
      end
    end

    def problems
      unowned = (@models.keys - ownership.keys - pending).map { |name| "#{name} has no owning feature (create openspec/specs/<feature>/models/#{ModelDocs.page_name(name)} with its marker block)" }
      graduated = (pending & ownership.keys).map { |name| "#{name} is documented now: remove it from #{PENDING_LIST}" }
      unknown_pending = (pending - @models.keys).map { |name| "#{PENDING_LIST} names unknown model #{name}" }
      shared = ownership.select { |_, paths| paths.size > 1 }.map { |name, paths| "#{name} is owned by more than one feature: #{paths.join(", ")}" }
      unknown = (ownership.keys - @models.keys).map { |name| "#{ownership[name].join(", ")} documents unknown model #{name}" }
      misplaced = ownership.flat_map do |name, paths|
        paths.reject { |path| File.basename(path) == ModelDocs.page_name(name) && File.basename(File.dirname(path)) == "models" }
             .map { |path| "#{name} must be documented in openspec/specs/<feature>/models/#{ModelDocs.page_name(name)}, not #{path}" }
      end
      tableless = @models.values.reject(&:table_exists?).map { |model| "#{model.name} has no table #{model.table_name}" }
      unowned + graduated + unknown_pending + shared + unknown + misplaced + tableless
    end

    # { relative_path => expected_content }
    def expected_files
      files = documents.to_h { |path| [ relative(path), render_document(path) ] }
      features.each do |feature|
        files["openspec/specs/#{feature}/diagrams/data-model.mmd"] = render_feature_diagram(feature)
      end
      files[GLOBAL_DIAGRAM] = render_global_diagram
      files
    end

    def stale_files
      expected_files.reject { |path, content| @root.join(path).exist? && @root.join(path).read == content }.keys
    end

    def write!
      expected_files.each do |path, content|
        file = @root.join(path)
        next if file.exist? && file.read == content

        file.dirname.mkpath
        file.write(content)
      end
    end

    private
      def documents
        Pathname.glob(@root.join(MODEL_DOCS_GLOB)).sort
      end

      def features
        ownership.values.flatten.map { |path| path.split("/")[2] }.uniq.sort
      end

      def drawable
        @drawable ||= @models.values.select(&:table_exists?)
      end

      # Relative link from a page to the owning page of another model (its base's, for a subclass).
      def link_from(page, target)
        owner = ownership[target.base_class.name]&.first or return nil
        @root.join(owner).relative_path_from(page.dirname).to_s
      end

      def owned_models(feature)
        ownership.select { |_, paths| paths.any? { |path| path.split("/")[2] == feature } }.keys
                 .filter_map { |name| @models[name] }.select(&:table_exists?)
      end

      def relative(path)
        path.relative_path_from(@root).to_s
      end

      def render_document(path)
        path.read.gsub(MODEL_BLOCK) do
          name = Regexp.last_match(1)
          model = @models[name]
          body =
            if model.nil? then "_Unknown model #{name}._\n"
            elsif !model.table_exists? then "_#{name} has no table (`#{model.table_name}`)._\n"
            else Summary.new(model, link_to: ->(target) { link_from(path, target) }).to_markdown
            end
          # Blank lines around the block so Markdown renders the table.
          "<!-- BEGIN generated: model #{name} -->\n\n#{body}\n<!-- END generated: model #{name} -->"
        end
      end

      def render_feature_diagram(feature)
        <<~MMD + ErDiagram.new(owned_models(feature), owner_of: method(:owner_feature)).to_mermaid
          %% GENERATED by `bin/rails docs:models`. Do not edit by hand.
          %% Models owned by #{feature}, plus stubs of the models they borrow.
        MMD
      end

      def render_global_diagram
        <<~MMD + ErDiagram.new(drawable).to_mermaid
          %% GENERATED by `bin/rails docs:models` from the ActiveRecord models. Do not edit by hand.
          %% Implemented models only; planned models live in their OpenSpec change until built.
          %% Each model is documented in its owning feature: openspec/specs/<feature>/models/<model>.md
        MMD
      end

      def owner_feature(model)
        path = ownership[model.base_class.name]&.first
        path && path.split("/")[2]
      end
  end
end
