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
        node.type = Builtins.common_type([node.then_expr.type, node.else_expr.type])
        unless node.type
          raise SignatureError,
                "Conditional branches have incompatible types: #{node.then_expr.type} and #{node.else_expr.type}"
        end
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
          validate_return_types!(node) if node.return_type
          node.type = node.return_type
        end

        node
      end

      private

      def validate_return_types!(function)
        expressions = explicit_return_expressions(function.body)
        expressions.concat(terminal_expressions(function.body))
        expressions.uniq.each do |expression|
          next if compatible_return?(function.return_type, expression)

          raise SignatureError,
                "Function #{function.name} returns #{return_type_of(expression).inspect}, expected #{function.return_type.inspect}"
        end
      end

      def explicit_return_expressions(node)
        case node
        when IR::Block
          node.statements.flat_map { |statement| explicit_return_expressions(statement) }
        when IR::IfStatement
          explicit_return_expressions(node.then_branch) + explicit_return_expressions(node.else_branch)
        when IR::ForLoop, IR::WhileLoop
          explicit_return_expressions(node.body)
        when IR::Return
          node.expression ? [node.expression] : []
        else
          []
        end
      end

      def terminal_expressions(node)
        case node
        when IR::Block
          terminal_expressions(node.statements.last)
        when IR::IfStatement
          terminal_expressions(node.then_branch) + terminal_expressions(node.else_branch)
        when IR::Return, nil
          []
        else
          node.type ? [node] : []
        end
      end

      def compatible_return?(expected, expression)
        if expected.is_a?(Array)
          actual = return_type_of(expression)
          return false unless actual.is_a?(Array) && actual.length == expected.length

          return expected.zip(actual).all? { |expected_type, actual_type| compatible_type?(expected_type, actual_type) }
        end

        compatible_type?(expected, expression.type)
      end

      def return_type_of(expression)
        return expression.elements.map(&:type) if expression.is_a?(IR::ArrayLiteral)
        return expression.type.types if expression.type.is_a?(IR::TupleType)

        expression.type
      end

      def compatible_type?(expected, actual)
        expected == actual || (expected == :float && actual == :int)
      end
    end
  end
end
