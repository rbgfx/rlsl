# frozen_string_literal: true

require_relative "builtins/function_registry"
require_relative "builtins/operator_rules"
require_relative "builtins/swizzle_rules"

module RLSL
  module Prism
    module Builtins
      FUNCTIONS = FunctionRegistry::FUNCTIONS
      BINARY_OPERATORS = OperatorRules::BINARY_OPERATORS
      UNARY_OPERATORS = OperatorRules::UNARY_OPERATORS
      SWIZZLE_COMPONENTS = SwizzleRules::SWIZZLE_COMPONENTS
      SINGLE_COMPONENT_FIELDS = SwizzleRules::SINGLE_COMPONENT_FIELDS
      SWIZZLE_PATTERNS = SwizzleRules::SWIZZLE_PATTERNS

      class << self
        def function?(name)
          FunctionRegistry.function?(name)
        end

        def function_signature(name)
          FunctionRegistry.function_signature(name)
        end

        def supported_on_target?(name, target)
          FunctionRegistry.supported_on_target?(name, target)
        end

        def explicit_types(name)
          FunctionRegistry.explicit_types(name)
        end

        def binary_operator?(op)
          OperatorRules.binary_operator?(op)
        end

        def unary_operator?(op)
          OperatorRules.unary_operator?(op)
        end

        def single_component_field?(name)
          SwizzleRules.single_component_field?(name)
        end

        def swizzle?(name)
          SwizzleRules.swizzle?(name)
        end

        def swizzle_type(components)
          SwizzleRules.swizzle_type(components)
        end

        def valid_swizzle_for_type?(components, receiver_type)
          SwizzleRules.valid_for_type?(components, receiver_type)
        end

        def resolve_return_type(rule, arg_types)
          FunctionRegistry.resolve_return_type(rule, arg_types)
        end

        def binary_op_result_type(op, left_type, right_type)
          OperatorRules.binary_op_result_type(op, left_type, right_type)
        end

        def vector_type?(type)
          OperatorRules.vector_type?(type)
        end

        def matrix_type?(type)
          OperatorRules.matrix_type?(type)
        end

        def scalar_type?(type)
          OperatorRules.scalar_type?(type)
        end

        def common_type(types)
          OperatorRules.common_type(types)
        end

        def matrix_vector_result(matrix_type)
          OperatorRules.matrix_vector_result(matrix_type)
        end
      end
    end
  end
end
