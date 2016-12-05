module ScopedSearch

  # The ScopedSearch definition class defines on what fields should be search
  # in the model in what cases
  #
  # A definition can be created by calling the <tt>scoped_search</tt> method on
  # an ActiveRecord-based class, so you should not create an instance of this
  # class yourself.
  class Definition

    # The Field class specifies a field of a model that is available for searching,
    # in what cases this field should be searched and its default search behavior.
    #
    # Instances of this class are created when calling scoped_search in your model
    # class, so you should not create instances of this class yourself.
    class Field

      attr_reader :definition, :field, :only_explicit, :relation, :key_relation, :full_text_search,
                  :key_field, :complete_value, :complete_enabled, :offset, :word_size, :ext_method, :operators,
                  :validator

      # Initializes a Field instance given the definition passed to the
      # scoped_search call on the ActiveRecord-based model class.
      #
      # Field name may be given in positional 'field' argument or 'on' named
      # argument.
      def initialize(definition,
                     field = nil,
                     aliases: [],
                     complete_enabled: true,
                     complete_value: nil,
                     default_operator: nil,
                     default_order: nil,
                     ext_method: nil,
                     full_text_search: nil,
                     in_key: nil,
                     offset: nil,
                     on: field,
                     on_key: nil,
                     only_explicit: nil,
                     operators: nil,
                     profile: nil,
                     relation: nil,
                     rename: nil,
                     validator: nil,
                     word_size: 1,
                     **kwargs)

        # Prefer 'on' kw arg if given, defaults to the 'field' positional to allow either syntax
        raise ArgumentError, "Missing field or 'on' keyword argument" if on.nil?
        @field = on.to_sym

        # Reserved Ruby keywords so access via kwargs instead, but deprecate them for future versions
        if kwargs.key?(:in)
          relation = kwargs.delete(:in)
          ActiveSupport::Deprecation.warn("'in' argument deprecated, prefer 'relation' since scoped_search 4.0.0", caller(6))
        end
        if kwargs.key?(:alias)
          aliases += [kwargs.delete(:alias)]
          ActiveSupport::Deprecation.warn("'alias' argument deprecated, prefer aliases: [..] since scoped_search 4.0.0", caller(6))
        end
        raise ArgumentError, "Unknown arguments to scoped_search: #{kwargs.keys.join(', ')}" unless kwargs.empty?

        @definition = definition
        @definition.profile = profile if profile
        @definition.default_order ||= generate_default_order(default_order, rename || @field) if default_order

        # Set attributes from keyword arguments
        @complete_enabled = complete_enabled
        @complete_value   = complete_value
        @default_operator = default_operator
        @ext_method       = ext_method
        @full_text_search = full_text_search
        @key_field        = on_key
        @key_relation     = in_key
        @offset           = offset
        @only_explicit    = !!only_explicit
        @operators        = operators
        @relation         = relation
        @validator        = validator
        @word_size        = word_size

        # Store this field in the field array
        definition.fields[rename ? rename.to_sym : @field] ||= self
        definition.unique_fields << self

        # Store definition for aliases as well
        aliases.each { |al| definition.fields[al.to_sym] ||= self }
      end

      # The ActiveRecord-based class that belongs to this field.
      def klass
        @klass ||= if relation
          definition.reflection_by_name(definition.klass, relation).klass
        else
          definition.klass
        end
      end

      # The ActiveRecord-based class that belongs the key field in a key-value pair.
      def key_klass
        @key_klass ||= if key_relation
          definition.reflection_by_name(definition.klass, key_relation).klass
        elsif relation
          definition.reflection_by_name(definition.klass, relation).klass
        else
          definition.klass
        end
      end

      # Returns the ActiveRecord column definition that corresponds to this field.
      def column
        @column ||= begin
          if klass.columns_hash.has_key?(field.to_s)
            klass.columns_hash[field.to_s]
          else
            if "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}".to_f < 4.1
              raise ActiveRecord::UnknownAttributeError, "#{klass.inspect} doesn't have column #{field.inspect}."
            else
              raise ActiveRecord::UnknownAttributeError.new(klass, field)
            end
          end
        end
      end

      # Returns the column type of this field.
      def type
        @type ||= column.type
      end

      # Returns true if this field is a datetime-like column
      def datetime?
        [:datetime, :time, :timestamp].include?(type)
      end

      # Returns true if this field is a date-like column
      def date?
        type == :date
      end

      # Returns true if this field is a date or datetime-like column.
      def temporal?
        datetime? || date?
      end

      # Returns true if this field is numerical.
      # Numerical means either integer, floating point or fixed point.
      def numerical?
        [:integer, :double, :float, :decimal].include?(type)
      end

      # Returns true if this is a textual column.
      def textual?
        [:string, :text].include?(type)
      end

      # Returns true if this is a set.
      def set?
        complete_value.is_a?(Hash)
      end

      # Returns the default search operator for this field.
      def default_operator
        @default_operator ||= case type
          when :string, :text then :like
          else :eq
        end
      end

      def generate_default_order(default_order, field)
        order = (default_order.to_s.downcase.include?('desc')) ? "DESC" : "ASC"
        return "#{field} #{order}"
      end

      # Return 'table'.'column' with the correct database quotes
      def quoted_field
        c = klass.connection
        "#{c.quote_table_name(klass.table_name)}.#{c.quote_column_name(field)}"
      end
    end

    DEFAULT_DATE_PARSER = lambda do |input|
      begin
        DateTime.parse(input, true)
      rescue ArgumentError
        nil
      end
    end

    attr_reader :klass

    # Initializes a ScopedSearch definition instance.
    # This method will also setup a database adapter and create the :search_for
    # named scope if it does not yet exist.
    def initialize(klass)
      @klass                 = klass
      @fields                = {}
      @unique_fields         = []
      @profile_fields        = {:default => {}}
      @profile_unique_fields = {:default => []}
      @date_parser           = DEFAULT_DATE_PARSER

      register_named_scope! unless klass.respond_to?(:search_for)
      register_complete_for! unless klass.respond_to?(:complete_for)
    end

    attr_accessor :profile, :default_order, :date_parser

    def fields
      @profile ||= :default
      @profile_fields[@profile] ||= {}
    end

    def unique_fields
      @profile ||= :default
      @profile_unique_fields[@profile] ||= []
    end

    # this method return definitions::field object from string
    def field_by_name(name)
      field = fields[name.to_sym] unless name.blank?
      if field.nil?
        dotted = name.to_s.split('.')[0]
        field = fields[dotted.to_sym] unless dotted.blank?
      end
      field
    end

    # this method is used by the syntax auto completer to suggest operators.
    def operator_by_field_name(name)
      field = field_by_name(name)
      return [] if field.nil?
      return field.operators                                      if field.operators
      return ['= ', '!= ']                                        if field.set?
      return ['= ', '> ', '< ', '<= ', '>= ','!= ', '^ ', '!^ ']  if field.numerical?
      return ['= ', '!= ', '~ ', '!~ ', '^ ', '!^ ']              if field.textual?
      return ['= ', '> ', '< ']                                   if field.temporal?
      raise ScopedSearch::QueryNotSupported, "Unsupported type '#{field.type.inspect}')' for field '#{name}'. This can be a result of a search definition problem."
    end

    NUMERICAL_REGXP = /^\-?\d+(\.\d+)?$/
    INTEGER_REGXP = /^\-?\d+$/

    # Returns a list of appropriate fields to search in given a search keyword and operator.
    def default_fields_for(value, operator = nil)

      column_types  = []
      column_types += [:string, :text]                if [nil, :like, :unlike, :ne, :eq].include?(operator)
      column_types += [:double, :float, :decimal]     if value =~ NUMERICAL_REGXP
      column_types += [:integer]                      if value =~ INTEGER_REGXP
      column_types += [:datetime, :date, :timestamp]  unless date_parser.call(value).nil?

      default_fields.select { |field| column_types.include?(field.type) && !field.set? }
    end

    # Returns a list of fields that should be searched on by default.
    #
    # Every field will show up in this method's result, except for fields for
    # which the only_explicit parameter is set to true.
    def default_fields
      unique_fields.reject { |field| field.only_explicit }
    end

    # Defines a new search field for this search definition.
    def define(*args)
      Field.new(self, *args)
    end

    # Returns a reflection for a given klass and name
    def reflection_by_name(klass, name)
      return if name.nil?
      klass.reflections[name.to_sym] || klass.reflections[name.to_s]
    end

    protected

    # Registers the search_for named scope within the class that is used for searching.
    def register_named_scope! # :nodoc
      definition = self
      @klass.scope(:search_for, proc { |query, options|
        klass = definition.klass

        search_scope = case ActiveRecord::VERSION::MAJOR
          when 3
            klass.scoped
          when 4
            (ActiveRecord::VERSION::MINOR < 1) ? klass.where(nil) : klass.all
          when 5
            klass.all
          else
            raise ScopedSearch::DefinitionError, 'version ' \
              "#{ActiveRecord::VERSION::MAJOR} of activerecord is not supported"
          end

        find_options = ScopedSearch::QueryBuilder.build_query(definition, query || '', options || {})
        search_scope = search_scope.where(find_options[:conditions])   if find_options[:conditions]
        search_scope = search_scope.includes(find_options[:include])   if find_options[:include]
        search_scope = search_scope.joins(find_options[:joins])        if find_options[:joins]
        search_scope = search_scope.reorder(find_options[:order])      if find_options[:order]
        search_scope = search_scope.references(find_options[:include]) if find_options[:include] && ActiveRecord::VERSION::MAJOR >= 4

        search_scope
      })
    end

    # Registers the complete_for method within the class that is used for searching.
    def register_complete_for! # :nodoc
      @klass.extend(ScopedSearch::AutoCompleteClassMethods)
    end
  end

  module AutoCompleteClassMethods
    def complete_for(query, options = {})
      ScopedSearch::AutoCompleteBuilder.auto_complete(scoped_search_definition, query, options)
    end
  end
end
