# frozen_string_literal: true

module RLSL
  module Prism
    class ExpressionInferer
      def initialize(infer:, lookup:, call_type_resolver:, field_type_resolver:, collection_type_resolver:)
        @infer = infer
        @lookup = lookup
        @call_type_resolver = call_type_resolver
        @field_type_resolver = field_type_resolver
        @collection_type_resolver = collection_type_resolver
      end

      def infer_var_ref(node)
        node.type ||= @lookup.call(node.name)
        node
      end

      def infer_literal(node)
        node
      end

      def infer_bool_literal(node)
        node.type = :bool
        node
      end

      def infer_binary_op(node)
        @infer.call(node.left)
        @infer.call(node.right)

        node.type = Builtins.binary_op_result_type(
          node.operator,
          node.left.type,
          node.right.type
        )
        node
      end

      def infer_unary_op(node)
        @infer.call(node.operand)

        case node.operator.to_s
        when "-"
          node.type = node.operand.type
        when "!"
          node.type = :bool
        end
        node
      end

      def infer_func_call(node)
        node.args.each { |arg| @infer.call(arg) }
        @infer.call(node.receiver) if node.receiver

        node.type = @call_type_resolver.resolve(node)
        node
      end

      def infer_field_access(node)
        @infer.call(node.receiver)
        node.type = @field_type_resolver.resolve(node)
        node
      end

      def infer_swizzle(node)
        @infer.call(node.receiver)
        unless Builtins.valid_swizzle_for_type?(node.components, node.receiver.type)
          raise SignatureError, "Invalid swizzle #{node.components.inspect} for #{node.receiver.type || :unknown}"
        end

        node.type = Builtins.swizzle_type(node.components)
        node
      end

      def infer_parenthesized(node)
        @infer.call(node.expression)
        node.type = node.expression.type
        node
      end

      def infer_array_literal(node)
        node.elements.each { |element| @infer.call(element) }
        node.type = @collection_type_resolver.resolve_array_literal(node)
        node
      end

      def infer_array_index(node)
        @infer.call(node.array)
        @infer.call(node.index)
        node.type = @collection_type_resolver.resolve_array_index(node)
        node
      end
    end
  end
end
