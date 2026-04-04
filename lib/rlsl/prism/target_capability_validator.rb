# frozen_string_literal: true

require_relative "../types"
require_relative "type_inference/type_shapes"

module RLSL
  module Prism
    class TargetCapabilityError < StandardError; end

    class TargetCapabilityValidator
      include TypeShapes

      def validate!(node, target)
        @target = target.to_sym
        validate_node!(node)
        node
      end

      private

      attr_reader :target

      def validate_node!(node)
        return if node.nil?

        validate_type!(node.type, context: node.class.name.split("::").last)

        case node
        when IR::Block
          node.statements.each { |statement| validate_node!(statement) }
        when IR::VarDecl
          validate_node!(node.initializer)
        when IR::BinaryOp
          validate_node!(node.left)
          validate_node!(node.right)
        when IR::UnaryOp
          validate_node!(node.operand)
        when IR::FuncCall
          validate_builtin!(node)
          validate_node!(node.receiver)
          node.args.each { |arg| validate_node!(arg) }
        when IR::FieldAccess
          validate_node!(node.receiver)
        when IR::Swizzle
          validate_node!(node.receiver)
        when IR::IfStatement
          validate_node!(node.condition)
          validate_node!(node.then_branch)
          validate_node!(node.else_branch)
        when IR::Ternary
          validate_node!(node.condition)
          validate_node!(node.then_expr)
          validate_node!(node.else_expr)
        when IR::Return
          validate_node!(node.expression)
        when IR::Assignment
          validate_node!(node.target)
          validate_node!(node.value)
        when IR::ForLoop
          validate_node!(node.range_start)
          validate_node!(node.range_end)
          validate_node!(node.body)
        when IR::WhileLoop
          validate_node!(node.condition)
          validate_node!(node.body)
        when IR::Parenthesized
          validate_node!(node.expression)
        when IR::FunctionDefinition
          validate_type!(node.return_type, context: "function #{node.name} return")
          node.param_types.each_value do |type|
            validate_type!(type, context: "function #{node.name} parameter")
          end
          validate_node!(node.body)
        when IR::ArrayLiteral
          node.elements.each { |element| validate_node!(element) }
        when IR::ArrayIndex
          validate_node!(node.array)
          validate_node!(node.index)
        when IR::GlobalDecl
          validate_type!(node.element_type, context: "global #{node.name} element")
          validate_node!(node.initializer)
        when IR::MultipleAssignment
          node.targets.each { |target| validate_node!(target) }
          validate_node!(node.value)
        end
      end

      def validate_builtin!(node)
        return unless Builtins.function?(node.name)

        unless Builtins.supported_on_target?(node.name, target)
          raise TargetCapabilityError, "Builtin #{node.name} is not supported on #{target.to_s.upcase}"
        end

        Builtins.explicit_types(node.name).each do |type|
          validate_type!(type, context: "builtin #{node.name}")
        end
      end

      def validate_type!(type, context:)
        return if type.nil?

        if TypeShapes.array?(type)
          validate_type!(TypeShapes.element_type(type), context: "#{context} array element")
          return
        end

        if type.is_a?(Array)
          type.each { |element_type| validate_type!(element_type, context: "#{context} tuple element") }
          return
        end

        if type.is_a?(IR::TupleType)
          type.types.each { |element_type| validate_type!(element_type, context: "#{context} tuple element") }
          return
        end

        return unless uniform_type_symbol?(type)

        return if RLSL::UniformTypes.fetch(type).target_supported?(target)

        raise TargetCapabilityError,
              "Unsupported #{target.to_s.upcase} type #{type.inspect} in #{context}"
      rescue ArgumentError
        nil
      end

      def uniform_type_symbol?(type)
        type.is_a?(Symbol) && RLSL::UNIFORM_TYPES.include?(type)
      end
    end
  end
end
