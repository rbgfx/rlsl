# frozen_string_literal: true

module RLSL
  module UniformTypes
    module Catalog
      def fetch(type)
        UNIFORM_TYPE_SPECS.fetch(type) do
          raise ArgumentError, "Unsupported uniform type: #{type.inspect}"
        end
      end

      def c_type(type)
        fetch(type).c_type
      end

      def compiled_types
        @compiled_types ||= UNIFORM_TYPE_SPECS.select { |_type, spec| spec.compiled? }.keys.freeze
      end

      def compiled_spec(type)
        spec = fetch(type)
        return spec if spec.compiled?

        raise ArgumentError, "Unsupported compiled uniform type: #{type}"
      end

      def metal_spec(type)
        spec = fetch(type)
        return spec if spec.metal_packable?

        raise ArgumentError, "Unsupported Metal uniform type: #{type}"
      end

      def runtime_types
        @runtime_types ||= UNIFORM_TYPE_SPECS.select { |_type, spec| spec.runtime_supported? }.keys.freeze
      end

      def function_shorthand_types
        @function_shorthand_types ||= UNIFORM_TYPE_SPECS.select { |_type, spec| spec.function_shorthand? }.keys.freeze
      end
    end
  end
end
