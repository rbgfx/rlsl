# frozen_string_literal: true

module RLSL
  module Prism
    class ControlFlowInferer
      def initialize(infer:, infer_in_scope:, lookup:)
        @infer = infer
        @infer_in_scope = infer_in_scope
        @lookup = lookup
      end

      def infer_if_statement(node)
        @infer.call(node.condition)
        if node.hoisted_variables.empty?
          @infer.call(node.then_branch, scoped: true)
          @infer.call(node.else_branch, scoped: true) if node.else_branch
        else
          @infer.call(node.then_branch)
          @infer.call(node.else_branch) if node.else_branch
        end

        node.hoisted_variables.each_key do |name|
          node.hoisted_variables[name] = @lookup.call(name)
        end

        node.type = node.then_branch&.type
        node
      end

      def infer_ternary(node)
        @infer.call(node.condition)
        @infer.call(node.then_expr)
        @infer.call(node.else_expr)
        node.type = node.then_expr.type
        node
      end

      def infer_return(node)
        @infer.call(node.expression) if node.expression
        node.type = node.expression&.type
        node
      end

      def infer_for_loop(node)
        @infer.call(node.range_start)
        @infer.call(node.range_end)
        unless node.range_start.type == :int && node.range_end.type == :int
          raise SignatureError,
                "Loop bounds must be integers, got #{node.range_start.type.inspect} and #{node.range_end.type.inspect}"
        end

        @infer_in_scope.call(node.variable => :int) do
          @infer.call(node.body)
        end

        node.type = nil
        node
      end

      def infer_while_loop(node)
        @infer.call(node.condition)
        @infer.call(node.body, scoped: true)
        node.type = nil
        node
      end

      def infer_function_definition(node)
        @infer_in_scope.call(node.param_types) do
          @infer.call(node.body)

          node.return_type ||= node.body&.type
          node.type = node.return_type
        end

        node
      end
    end
  end
end
