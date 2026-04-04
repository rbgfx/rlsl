# frozen_string_literal: true

module RLSL
  module Prism
    class ControlFlowInferer
      def initialize(infer:, infer_child_scope:, infer_in_scope:)
        @infer = infer
        @infer_child_scope = infer_child_scope
        @infer_in_scope = infer_in_scope
      end

      def infer_if_statement(node)
        @infer.call(node.condition)
        @infer_child_scope.call(node.then_branch)
        @infer_child_scope.call(node.else_branch) if node.else_branch

        node.type = node.then_branch.type
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

        @infer_in_scope.call(node.variable => :int) do
          @infer.call(node.body)
        end

        node.type = nil
        node
      end

      def infer_while_loop(node)
        @infer.call(node.condition)
        @infer_child_scope.call(node.body)
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
