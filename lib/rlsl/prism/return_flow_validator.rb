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
        IR::ArrayLiteral,
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

          validate_returning_block!(current.body, "function #{current.name}")
        end
      end

      def validate_returning_block!(node, context)
        return if returns_value_on_all_paths?(node)

        raise ReturnFlowError.new(
          "#{context} does not return a value on every path"
        ).with_source_location(node.location)
      end

      def returns_value_on_all_paths?(node)
        case node
        when IR::Block
          returns_value_on_all_paths?(node.statements.last)
        when IR::Return
          !node.expression.nil?
        when IR::IfStatement
          node.else_branch &&
            returns_value_on_all_paths?(node.then_branch) &&
            returns_value_on_all_paths?(node.else_branch)
        else
          VALUE_NODES.any? { |klass| node.is_a?(klass) }
        end
      end
    end
  end
end
