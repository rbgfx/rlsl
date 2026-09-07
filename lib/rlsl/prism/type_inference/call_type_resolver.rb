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

        raise SignatureError, "Unknown shader function #{node.name}"
      end

      private

      def resolve_builtin(node, signature)
        arg_types = effective_arg_types(node)
        @call_validator.validate_builtin!(node, arg_types, signature)
        return_type = Builtins.resolve_return_type(signature[:returns], arg_types)
        unless return_type
          raise SignatureError, "Incompatible argument types for #{node.name}: #{arg_types.join(', ')}"
        end

        node.expected_arg_types = expected_builtin_types(signature, arg_types.length, return_type)
        return_type
      end

      def resolve_custom(node, signature)
        @call_validator.validate_custom!(node.name, effective_arg_types(node), signature)
        node.expected_arg_types = signature[:params]&.values || []
        signature[:returns]
      end

      def effective_arg_types(node)
        types = node.args.map(&:type)
        node.receiver ? [node.receiver.type, *types] : types
      end

      def expected_builtin_types(signature, argument_count, return_type)
        expected = signature[:args].first(argument_count)
        case signature[:returns]
        when :common, :floating
          expected.map { |type| type == :any ? return_type : type }
        when :interpolated
          expected.each_with_index.map { |type, index| index < 2 && type == :any ? return_type : type }
        else
          expected
        end
      end
    end
  end
end
