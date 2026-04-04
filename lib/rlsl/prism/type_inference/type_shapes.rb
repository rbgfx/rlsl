# frozen_string_literal: true

module RLSL
  module Prism
    module TypeShapes
      ArrayType = Struct.new(:element_type) do
        def to_sym
          :"array_#{element_type}"
        end

        def to_s
          to_sym.to_s
        end
      end

      module_function

      def array(element_type)
        ArrayType.new(element_type)
      end

      def array?(type)
        type.is_a?(ArrayType)
      end

      def element_type(type)
        return type.element_type if array?(type)

        nil
      end
    end
  end
end
