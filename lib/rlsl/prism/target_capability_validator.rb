# frozen_string_literal: true

require_relative "../types"
require_relative "ir/traversal"
require_relative "type_inference/type_shapes"

module RLSL
  module Prism
    class TargetCapabilityError < StandardError; end

    class TargetCapabilityValidator
      include TypeShapes

      def validate!(node, target)
        @target = target.to_sym
        IR::Traversal.each(node) { |current| validate_node!(current) }
        node
      end

      private

      attr_reader :target

      def validate_node!(node)
        return if node.nil?

        validate_type!(node.type, context: node.class.name.split("::").last)

        case node
        when IR::FuncCall
          validate_builtin!(node)
        when IR::FunctionDefinition
          validate_type!(node.return_type, context: "function #{node.name} return")
          node.param_types.each_value do |type|
            validate_type!(type, context: "function #{node.name} parameter")
          end
        when IR::GlobalDecl
          validate_type!(node.element_type, context: "global #{node.name} element")
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
      end

      def uniform_type_symbol?(type)
        type.is_a?(Symbol) && RLSL::UniformTypes.supported?(type)
      end
    end
  end
end
