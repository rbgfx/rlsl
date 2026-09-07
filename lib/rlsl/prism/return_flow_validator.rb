# frozen_string_literal: true

require_relative "ir/traversal"

module RLSL
  module Prism
    class ReturnFlowError < RLSL::Error; end

    class ReturnFlowValidator
      VALUE_NODES = [
        IR::VarDecl,
        IR::Assignment,
        IR::VarRef,
        IR::Literal,
        IR::BoolLiteral,
        IR::BinaryOp,
        IR::UnaryOp,
        IR::FuncCall,
        IR::FieldAccess,
        IR::Swizzle,
        IR::Ternary,
        IR::Constant,
        IR::Parenthesized,
        IR::ArrayIndex
      ].freeze

      def validate!(node, needs_return:)
        validate_functions!(node)
        validate_returning_block!(node, "shader fragment") if needs_return
        node
      end

      private

      def validate_functions!(node)
        IR::Traversal.each(node) do |current|
          next unless current.is_a?(IR::FunctionDefinition)

          validate_returning_block!(
            current.body,
            "function #{current.name}",
            tuple_return: current.return_type.is_a?(Array)
          )
        end
      end

      def validate_returning_block!(node, context, tuple_return: false)
        return if returns_value_on_all_paths?(node, tuple_return: tuple_return)

        raise ReturnFlowError.new(
          "#{context} does not return a value on every path"
        ).with_source_location(node.location)
      end

      def returns_value_on_all_paths?(node, tuple_return: false)
        case node
        when IR::Block
          returns_value_on_all_paths?(node.statements.last, tuple_return: tuple_return)
        when IR::Return
          !node.expression.nil? && (tuple_return || !node.expression.is_a?(IR::ArrayLiteral))
        when IR::IfStatement
          node.else_branch &&
            returns_value_on_all_paths?(node.then_branch, tuple_return: tuple_return) &&
            returns_value_on_all_paths?(node.else_branch, tuple_return: tuple_return)
        when IR::ArrayLiteral
          tuple_return
        else
          VALUE_NODES.any? { |klass| node.is_a?(klass) }
        end
      end
    end
  end
end
