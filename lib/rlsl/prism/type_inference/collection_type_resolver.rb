# frozen_string_literal: true

module RLSL
  module Prism
    class CollectionTypeResolver
      include TypeShapes

      def initialize(type_environment:, custom_functions:, register:)
        @type_environment = type_environment
        @custom_functions = custom_functions
        @register = register
      end

      def resolve_array_literal(node)
        element_type = node.elements.first&.type || :float
        TypeShapes.array(element_type)
      end

      def resolve_array_index(node)
        array_type = node.array.type
        return TypeShapes.element_type(array_type) if TypeShapes.array?(array_type)
        return @type_environment.array_element_type(node.array.name) || :float if node.array.is_a?(IR::VarRef)

        :float
      end

      def resolve_global_decl(node)
        if node.initializer.is_a?(IR::ArrayLiteral)
          node.array_size ||= node.initializer.elements.length
          first_elem = node.initializer.elements.first
          node.element_type ||= first_elem&.type || :float
          return TypeShapes.array(node.element_type)
        end

        node.initializer&.type
      end

      def assign_multiple_targets(node)
        value_type = node.value.type
        return assign_tuple_targets(node.targets, value_type.types) if value_type.is_a?(IR::TupleType)
        return assign_array_targets(node.targets, TypeShapes.element_type(value_type)) if TypeShapes.array?(value_type)
        return assign_custom_targets(node.targets, @custom_functions[node.value.name]) if custom_multi_return?(node.value)

        nil
      end

      private

      def assign_tuple_targets(targets, types)
        targets.each_with_index do |target, index|
          assign_target(target, types[index])
        end
      end

      def assign_array_targets(targets, type)
        targets.each do |target|
          assign_target(target, type)
        end
      end

      def assign_custom_targets(targets, signature)
        returns = signature[:returns]
        return unless returns.is_a?(Array)

        targets.each_with_index do |target, index|
          assign_target(target, returns[index])
        end
      end

      def assign_target(target, type)
        target.type = type
        @register.call(target.name, type)
      end

      def custom_multi_return?(value)
        value.is_a?(IR::FuncCall) && @custom_functions.key?(value.name)
      end
    end
  end
end
