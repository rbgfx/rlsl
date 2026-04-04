# frozen_string_literal: true

module RLSL
  module Prism
    class FieldTypeResolver
      def initialize(uniforms:)
        @uniforms = uniforms
      end

      def resolve(node)
        return :float if Builtins.single_component_field?(node.field)

        @uniforms[node.field.to_sym] || :float
      end
    end
  end
end
