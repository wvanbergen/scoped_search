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

      attr_reader :definition, :field, :only_explicit, :relation

      # The ActiveRecord-based class that belongs to this field.
      def klass
        if relation
          definition.klass.reflections[relation].klass
        else
          definition.klass
        end
      end

      # Returns the ActiveRecord column definition that corresponds to this field.
      def column
        klass.columns_hash[field.to_s]
      end

      # Returns the column type of this field.
      def type
        column.type
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

      # Returns the default search operator for this field.
      def default_operator
        @default_operator ||= case type
          when :string, :text then :like
          else :eq
        end
      end

      # Initializes a Field instance given the definition passed to the
      # scoped_search call on the ActiveRecord-based model class.
      def initialize(definition, options = {})
        @definition = definition
        @definition.profile = options[:profile] if options[:profile]
        
        case options
        when Symbol, String
          @field = field.to_sym
        when Hash
          @field = options.delete(:on)

          # Set attributes from options hash
          @relation         = options[:in]
          @only_explicit    = !!options[:only_explicit]
          @default_operator = options[:default_operator] if options.has_key?(:default_operator)
        end

        # Store this field is the field array
        definition.fields[@field] ||= self
        definition.unique_fields   << self

        # Store definition for alias / aliases as well
        definition.fields[options[:alias]] ||= self                    if options[:alias]
        options[:aliases].each { |al| definition.fields[al] ||= self } if options[:aliases]
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

      register_named_scope! unless klass.respond_to?(:search_for)
    end
    
    attr_accessor :profile
    
    def fields
      @profile ||= :default
      @profile_fields[@profile] ||= {}
    end

    def unique_fields
      @profile ||= :default
      @profile_unique_fields[@profile] ||= []
    end

    NUMERICAL_REGXP = /^\-?\d+(\.\d+)?$/

    # Returns a list of appropriate fields to search in given a search keyword and operator.
    def default_fields_for(value, operator = nil)

      column_types  = []
      column_types += [:string, :text]                      if [nil, :like, :unlike, :ne, :eq].include?(operator)
      column_types += [:integer, :double, :float, :decimal] if value =~ NUMERICAL_REGXP
      column_types += [:datetime, :date, :timestamp]        if (DateTime.parse(value) rescue nil)

      default_fields.select { |field| column_types.include?(field.type) }
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

    protected

    # Registers the search_for named scope within the class that is used for searching.
    def register_named_scope! # :nodoc
      if @klass.ancestors.include?(ActiveRecord::Base)
        case ActiveRecord::VERSION::MAJOR
        when 2
          @klass.named_scope(:search_for, lambda { |*args| ScopedSearch::QueryBuilder.build_query(self, args[0], args[1]) })
        when 3
          @klass.scope(:search_for, lambda { |*args| 
            find_options = ScopedSearch::QueryBuilder.build_query(self, args[0], args[1]) 
            search_scope = @klass.scoped
            search_scope = search_scope.where(find_options[:conditions]) if find_options[:conditions]
            search_scope = search_scope.includes(find_options[:include]) if find_options[:include]
            search_scope
          })
        else
          raise "This ActiveRecord version is currently not supported!"
        end
      else
        raise "Currently, only ActiveRecord 2.1 or higher is supported!"
      end
    end
  end
end
