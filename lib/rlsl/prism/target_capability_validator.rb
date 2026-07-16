# frozen_string_literal: true

require_relative "../types"
require_relative "ir/traversal"
require_relative "type_inference/type_shapes"

module RLSL
  module Prism
    class TargetCapabilityError < RLSL::Error; end

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

        validate_c_builtin_overload!(node) if target == :c
      end

      def validate_c_builtin_overload!(node)
        vector_types = node.args.map(&:type).select { |type| Builtins.vector_type?(type) }
        scalar_only = %i[sqrt abs sign floor ceil fract mod min max clamp step smoothstep]
        if scalar_only.include?(node.name.to_sym) && !vector_types.empty?
          raise TargetCapabilityError,
                "Builtin #{node.name} does not support vector arguments on C"
        end

        if %i[length normalize dot distance].include?(node.name.to_sym) && vector_types.empty?
          raise TargetCapabilityError, "Builtin #{node.name} requires vector arguments on C"
        end

        return unless %i[reflect refract].include?(node.name.to_sym)
        return if node.args.first&.type == :vec3 && node.args[1]&.type == :vec3

        raise TargetCapabilityError, "Builtin #{node.name} currently requires vec3 arguments on C"
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
