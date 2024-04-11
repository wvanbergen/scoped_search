module ScopedSearch
  module ValueTranslators
    class Encrypted
      def initialize(field)
        @type = field.klass.type_for_attribute(field.field)
      end

      def call(value)
        @type.serialize(value)
      end
    end
  end
end
