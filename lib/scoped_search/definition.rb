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
                  :key_field, :complete_value, :complete_enabled, :offset, :word_size, :ext_method, :operators

      # Initializes a Field instance given the definition passed to the
      # scoped_search call on the ActiveRecord-based model class.
      def initialize(definition, options = {})
        @definition = definition
        @definition.profile = options[:profile] if options[:profile]
        @definition.default_order ||= default_order(options)

        case options
        when Symbol, String
          @field = field.to_sym
        when Hash
          @field = options.delete(:on)

          # Set attributes from options hash
          @complete_value   = options[:complete_value]
          @relation         = options[:in]
          @key_relation     = options[:in_key]
          @key_field        = options[:on_key]
          @offset           = options[:offset]
          @word_size        = options[:word_size] || 1
          @ext_method       = options[:ext_method]
          @operators        = options[:operators]
          @only_explicit    = !!options[:only_explicit]
          @full_text_search = options[:full_text_search]
          @default_operator = options[:default_operator] if options.has_key?(:default_operator)
          @complete_enabled = options[:complete_enabled].nil? ? true : options[:complete_enabled]
        end

        # Store this field is the field array
        definition.fields[@field]                  ||= self unless options[:rename]
        definition.fields[options[:rename].to_sym] ||= self if     options[:rename]
        definition.unique_fields                   << self

        # Store definition for alias / aliases as well
        definition.fields[options[:alias].to_sym]                  ||= self   if options[:alias]
        options[:aliases].each { |al| definition.fields[al.to_sym] ||= self } if options[:aliases]
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

      def default_order(options)
        return nil if options[:default_order].nil?
        field_name = options[:rename].nil? ? options[:on] : options[:rename]
        order = (options[:default_order].to_s.downcase.include?('desc')) ? "DESC" : "ASC"
        return "#{field_name} #{order}"
      end

      # Return 'table'.'column' with the correct database quotes
      def quoted_field
        c = klass.connection
        "#{c.quote_table_name(klass.table_name)}.#{c.quote_column_name(field)}"
      end
    end

    attr_reader :klass

    # Initializes a ScopedSearch definition instance.
    # This method will also setup a database adapter and create the :search_for
    # named scope if it does not yet exist.
    # Initializes a ScopedSearch definition instance.
    # This method will also setup a database adapter and create the :search_for
    # named scope if it does not yet exist.
    def initialize(klass)
      @klass                 = klass
      @fields                = {}
      @unique_fields         = []
      @profile_fields        = {:default => {}}
      @profile_unique_fields = {:default => []}

      register_named_scope! unless klass.respond_to?(:search_for)
      register_complete_for! unless klass.respond_to?(:complete_for)
    end

    attr_accessor :profile, :default_order

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
      column_types += [:datetime, :date, :timestamp]  if (parse_temporal(value))

      default_fields.select { |field| column_types.include?(field.type) && !field.set? }
    end

    # Try to parse a string as a datetime.
    # Supported formats are Today, Yesterday, Sunday, '1 day ago', '2 hours ago', '3 months ago','Jan 23, 2004'
    # And many more formats that are documented in Ruby DateTime API Doc.
    def parse_temporal(value)
      return Date.current if value =~ /\btoday\b/i
      return 1.day.ago.to_date if value =~ /\byesterday\b/i
      return (eval($1.strip.gsub(/\s+/,'.').downcase)).to_datetime if value =~ /\A\s*(\d+\s+\b(?:hours?|minutes?)\b\s+\bago)\b\s*\z/i
      return (eval($1.strip.gsub(/\s+/,'.').downcase)).to_date     if value =~ /\A\s*(\d+\s+\b(?:days?|weeks?|months?|years?)\b\s+\bago)\b\s*\z/i
      DateTime.parse(value, true) rescue nil
    end

    # Returns a list of fields that should be searched on by default.
    #
    # Every field will show up in this method's result, except for fields for
    # which the only_explicit parameter is set to true.
    def default_fields
      unique_fields.reject { |field| field.only_explicit }
    end

    # Defines a new search field for this search definition.
    def define(options)
      Field.new(self, options)
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
