# frozen_string_literal: true

module RLSL
  module Prism
    class CallTypeResolver
      def initialize(custom_functions:, call_validator:)
        @custom_functions = custom_functions
        @call_validator = call_validator
      end

      def resolve(node)
        sig = Builtins.function_signature(node.name)
        return resolve_builtin(node, sig) if sig

        custom_function = @custom_functions[node.name.to_sym]
        return resolve_custom(node, custom_function) if custom_function

        node.receiver&.type
      end

      private

      def resolve_builtin(node, signature)
        arg_types = node.args.map(&:type)
        @call_validator.validate_builtin!(node, arg_types, signature)
        Builtins.resolve_return_type(signature[:returns], arg_types)
      end

      def resolve_custom(node, signature)
        @call_validator.validate_custom!(node.name, node.args.map(&:type), signature)
        signature[:returns]
      end
    end
  end
end
