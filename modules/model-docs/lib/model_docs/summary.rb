module ModelDocs
  # Markdown summary of one model: attributes, associations, enums, validations, scopes.
  class Summary
    HIDDEN_COLUMNS = %w[id created_at updated_at].freeze
    ASSOCIATION_OPTIONS = %i[dependent through optional inverse_of].freeze

    # link_to: ->(model_class) { "relative/path.md" or nil } for the page of
    # each model mentioned, so every reference to a model links to it.
    def initialize(model, link_to: ->(_model) { nil })
      @model = model
      @link_to = link_to
    end

    def to_markdown
      [ attributes_table, subclasses, associations, enums, validations, scopes ].compact.join("\n") + "\n"
    end

    private
      attr_reader :model

      def attributes_table
        # By name, as in db/schema.rb: the database's own order depends on how it was built
        columns = model.columns.sort_by(&:name).reject { |column| HIDDEN_COLUMNS.include?(column.name) }
        rows = columns.map do |column|
          "| `#{column.name}` | #{column.type} | #{column.null ? "yes" : "no"} | #{default(column)} | #{notes(column).join("; ")} |"
        end
        <<~MD
          ### Attributes

          | Attribute | Type | Null | Default | Notes |
          |---|---|---|---|---|
          #{rows.join("\n")}

          Also: #{(HIDDEN_COLUMNS & model.column_names).map { |name| "`#{name}`" }.join(", ")}.
        MD
      end

      def default(column)
        column.default.nil? ? "" : "`#{column.default}`"
      end

      def notes(column)
        notes = []
        if (index = unique_index_for(column.name))
          notes << (index.where ? "unique where `#{condition(index.where)}`" : "unique")
        end
        notes << "indexed" if indexed_columns.include?(column.name) && !unique_columns.include?(column.name)
        if (association = belongs_to_by_foreign_key[column.name]) && (klass = ModelDocs.klass_of(association))
          notes << "→ #{model_link(klass, klass.name)}"
        end
        notes << "enum: #{model.defined_enums[column.name].keys.join(", ")}" if model.defined_enums.key?(column.name)
        if column.name.end_with?("_digest")
          base = column.name.delete_suffix("_digest")
          notes << (base == "password" ? "has_secure_password" : "has_secure_password :#{base}") if model.method_defined?("authenticate_#{base}")
        end
        notes
      end

      def associations(of = model, except: [])
        items = (of.reflect_on_all_associations - except).map do |association|
          options = association.options.slice(*ASSOCIATION_OPTIONS).map { |key, value| "#{key}: #{value.inspect.delete_prefix(":")}" }
          options.unshift("polymorphic") if association.polymorphic?
          "- #{association.macro} #{association_target(association)}#{" (#{options.join(", ")})" if options.any?}"
        end
        section("Associations", items)
      end

      def enums
        return if model.defined_enums.empty?

        rows = model.defined_enums.map { |name, values| "| `#{name}` | #{values.keys.map { |value| "`#{value}`" }.join(", ")} |" }
        section("Enums", rows, "| Attribute | Values |\n|---|---|")
      end

      def validations(of = model, except: [])
        rows = (of.validators - except).map do |validator|
          options = validator.options.except(:message).map { |key, value| "#{key}: #{describe(value)}" }
          "| #{validator.attributes.map { |attribute| attribute_link(attribute) }.join(", ")} | #{validator.kind} | #{options.join(", ")} |"
        end
        section("Validations", rows, "| Attribute | Rule | Options |\n|---|---|---|")
      end

      def scopes(of = model)
        file = Object.const_source_location(of.name)&.first
        names = file ? File.read(file).scan(/^\s*scope :(\w+)/).flatten : []
        section("Scopes", names.map { |name| "- `#{name}`" })
      end

      # Single-table subclasses share this table and this page: each with what it declares of its own.
      def subclasses
        return if model.descendants.empty?

        parts = model.descendants.sort_by(&:name).map do |subclass|
          parent = subclass.superclass
          own = [ associations(subclass, except: parent.reflect_on_all_associations),
                  validations(subclass, except: parent.validators), scopes(subclass) ]
          "#### #{subclass.name}\n\n`#{model.inheritance_column}` = `#{subclass.sti_name}`\n\n" +
            own.map { |text| text.sub(/\A### /, "##### ") }.join("\n")
        end
        "### Subclasses\n\n#{parts.join("\n")}"
      end

      # PostgreSQL (test, production) rewrites a partial index's condition as
      # "((status)::text = 'pending'::text)"; SQLite (development) keeps it as written.
      # Both become "status = 'pending'", as in db/schema.rb.
      def condition(where)
        where.gsub(/::\w+(?: varying)?/, "").gsub(/\((\w+)\)/, '\1').sub(/\A\((.*)\)\z/, '\1')
      end

      def section(title, rows, header = nil)
        body = rows.any? ? [ header, *rows ].compact.join("\n") : "None."
        "### #{title}\n\n#{body}\n"
      end

      def model_link(klass, text)
        path = @link_to.call(klass)
        path ? "[#{text}](#{path})" : text
      end

      # "belongs_to User", or "belongs_to User as `opened_by`" when the
      # association isn't named after the model.
      def association_target(association)
        return "`#{association.name}`" if association.polymorphic?

        klass = ModelDocs.klass_of(association)
        return "`#{association.name}` (**broken**: its class cannot be loaded)" if klass.nil?

        default_name = klass.name.demodulize.underscore
        default_name = default_name.pluralize if association.collection?
        link = model_link(klass, klass.name)
        association.name.to_s == default_name ? link : "#{link} as `#{association.name}`"
      end

      # An attribute that is an association (e.g. `order_line` presence) links
      # to the associated model's page; plain columns stay as code.
      def attribute_link(attribute)
        association = model.reflect_on_association(attribute)
        klass = association && !association.polymorphic? && ModelDocs.klass_of(association)
        return "`#{attribute}`" unless klass

        model_link(klass, "`#{attribute}`")
      end

      def describe(value)
        case value
        when Regexp then "`#{value.inspect}`"
        when Proc then "(proc)"
        when Symbol then value.to_s
        when Array then value.map { |item| describe(item) }.join("/")
        else value.inspect
        end
      end

      def indexes
        @indexes ||= model.connection.indexes(model.table_name)
      end

      def unique_columns
        @unique_columns ||= indexes.select { |index| index.unique && index.columns.size == 1 }.flat_map(&:columns)
      end

      def unique_index_for(column_name)
        indexes.find { |index| index.unique && index.columns == [ column_name ] }
      end

      def indexed_columns
        @indexed_columns ||= indexes.select { |index| index.columns.size == 1 }.flat_map(&:columns)
      end

      def belongs_to_by_foreign_key
        @belongs_to_by_foreign_key ||= model.reflect_on_all_associations(:belongs_to)
          .reject(&:polymorphic?).index_by { |association| association.foreign_key.to_s }
      end
  end
end
