# frozen_string_literal: true

module RLSL
  module Prism
    class FieldTypeResolver
      def initialize(uniforms:)
        @uniforms = uniforms
      end

      def resolve(node)
        if Builtins.single_component_field?(node.field)
          unless Builtins.valid_swizzle_for_type?(node.field, node.receiver.type)
            raise SignatureError, "Invalid component #{node.field.inspect} for #{node.receiver.type || :unknown}"
          end

          return :float
        end

        if node.receiver.type == :uniforms
          type = @uniforms[node.field.to_sym]
          return type if type

          raise SignatureError, "Unknown uniform field #{node.field.inspect}"
        end

        raise SignatureError, "Unknown field #{node.field.inspect} for #{node.receiver.type || :unknown}"
      end
    end
  end
end
