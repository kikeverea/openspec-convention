module ModelDocs
  # Mermaid erDiagram for a set of models. Associated models outside the set
  # (owned by another feature) appear as plain boxes labelled with their
  # owning spec, e.g. "USER (staff)".
  class ErDiagram
    def initialize(models, owner_of: ->(_model) { nil })
      @models = models
      @owner_of = owner_of
    end

    def to_mermaid
      lines = [ "erDiagram" ]
      lines.concat(relationships.map { |line| "    #{line}" })
      @models.each { |model| lines.concat(entity(model)) }
      stubs.each do |model|
        owner = @owner_of.call(model)
        # Borrowed models are plain boxes (their fields are in the owning
        # feature's diagram), labelled with the owning spec in small text.
        label = owner ? "#{entity_name(model)}<br/><small>(#{owner})</small>" : entity_name(model)
        lines << "    #{entity_name(model)}[\"#{label}\"]"
      end
      lines.join("\n") + "\n"
    end

    private
      # One line per belongs_to, read from the parent's side when it declares the inverse.
      def relationships
        belongs_tos.map do |child, association|
          parent = association.klass.base_class
          inverse = parent.reflect_on_all_associations.find { |other| %i[has_many has_one].include?(other.macro) && other.klass.base_class == child && other.foreign_key.to_s == association.foreign_key.to_s }
          cardinality = inverse&.macro == :has_one ? "||--o|" : "||--o{"
          label = inverse ? inverse.name : "belongs_to #{association.name}"
          "#{entity_name(parent)} #{cardinality} #{entity_name(child)} : \"#{label}\""
        end.uniq
      end

      def belongs_tos
        connected = @models.flat_map do |model|
          model.reflect_on_all_associations(:belongs_to).reject(&:polymorphic?).map { |association| [ model, association ] }
        end
        # Also show borrowed parents' links into this set (e.g. a stub that belongs_to an owned model).
        connected + stubs.flat_map do |stub|
          stub.reflect_on_all_associations(:belongs_to).reject(&:polymorphic?)
              .select { |association| @models.include?(association.klass.base_class) }.map { |association| [ stub, association ] }
        end
      end

      def stubs
        @stubs ||= @models.flat_map do |model|
          model.reflect_on_all_associations.reject { |association| association.options[:polymorphic] || association.options[:through] }.map(&:klass)
        end.map(&:base_class).uniq.reject { |model| @models.include?(model) }.sort_by(&:name)
      end

      def entity(model)
        attributes = key_columns(model)
        return [ "    #{entity_name(model)} {", "        integer id PK", "    }" ] if attributes.empty?

        [ "    #{entity_name(model)} {", "        integer id PK", *attributes.map { |line| "        #{line}" }, "    }" ]
      end

      def key_columns(model)
        foreign_keys = model.reflect_on_all_associations(:belongs_to).map { |association| association.foreign_key.to_s }
        unique = model.connection.indexes(model.table_name).select { |index| index.unique && index.columns.size == 1 }.flat_map(&:columns)
        # By name, as in db/schema.rb: the database's own order depends on how it was built
        model.columns.sort_by(&:name).filter_map do |column|
          if foreign_keys.include?(column.name)
            "#{column.type} #{column.name} FK"
          elsif model.defined_enums.key?(column.name)
            "#{column.type} #{column.name} \"#{model.defined_enums[column.name].keys.join(" | ")}\""
          elsif unique.include?(column.name)
            "#{column.type} #{column.name} UK"
          end
        end
      end

      # Single-table subclasses are drawn as their base class, whose table they share.
      def entity_name(model)
        model.base_class.name.underscore.tr("/", "_").upcase
      end
  end
end
