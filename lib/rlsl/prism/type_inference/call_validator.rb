# frozen_string_literal: true

module RLSL
  module Prism
    class CallValidator
      def validate_builtin!(node, arg_types, signature)
        validate_signature!(
          node.name,
          arg_types,
          signature[:args],
          variadic: signature[:variadic],
          min_args: signature[:min_args]
        ) unless skip_builtin_validation?(node, signature)
      end

      def validate_custom!(name, arg_types, signature)
        params = signature[:params]
        unless params
          return if arg_types.empty?

          raise SignatureError, "Function #{name} requires explicit parameter types"
        end

        validate_signature!(name, arg_types, params.values)
      end

      private

      def validate_signature!(name, arg_types, expected_types, variadic: false, min_args: nil)
        validate_argument_count!(name, arg_types.length, expected_types.length, variadic: variadic, min_args: min_args)

        arg_types.each_with_index do |actual_type, index|
          expected_type = expected_types[index]
          next if compatible_argument_type?(expected_type, actual_type)

          raise SignatureError,
                "Invalid argument #{index + 1} for #{name}: expected #{expected_type}, got #{actual_type || :unknown}"
        end
      end

      def validate_argument_count!(name, actual_count, expected_count, variadic:, min_args:)
        return if valid_argument_count?(actual_count, expected_count, variadic: variadic, min_args: min_args)

        raise SignatureError,
              "Wrong number of arguments for #{name}: expected #{expected_count_description(expected_count, variadic, min_args)}, got #{actual_count}"
      end

      def valid_argument_count?(actual_count, expected_count, variadic:, min_args:)
        return actual_count == expected_count unless variadic

        minimum = min_args || expected_count
        actual_count.between?(minimum, expected_count)
      end

      def expected_count_description(expected_count, variadic, min_args)
        return expected_count.to_s unless variadic

        minimum = min_args || expected_count
        minimum == expected_count ? minimum.to_s : "#{minimum}..#{expected_count}"
      end

      def compatible_argument_type?(expected_type, actual_type)
        return true if expected_type == :any
        return true if expected_type == actual_type
        return true if expected_type == :float && actual_type == :int

        false
      end

      def skip_builtin_validation?(node, signature)
        signature[:variadic] && node.args.empty? && !node.type.nil?
      end
    end
  end
end
