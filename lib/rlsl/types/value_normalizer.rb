# frozen_string_literal: true

module RLSL
  module UniformTypes
    module ValueNormalizer
      def normalize_values(uniform_types, uniforms, shader_name: nil)
        uniform_types.each_with_object({}) do |(name, type), normalized|
          unless uniforms.key?(name)
            raise ArgumentError, missing_uniform_message(name, shader_name)
          end

          normalized[name] = normalize_value(type, uniforms[name], name: name, shader_name: shader_name)
        end
      end

      def normalize_value(type, value, name:, shader_name: nil)
        return value if type.nil?

        spec = fetch(type)
        raise ArgumentError, unsupported_runtime_type_message(type, shader_name) unless spec.runtime_supported?

        case spec.wrapper_kind
        when :float
          Float(value)
        when :int
          Integer(value)
        when :bool
          normalize_bool(value, name: name, shader_name: shader_name)
        when :vector
          normalize_vector(value, spec.vector_size, name: name, shader_name: shader_name)
        else
          raise ArgumentError, unsupported_runtime_type_message(type, shader_name)
        end
      rescue TypeError
        raise ArgumentError, invalid_uniform_message(name, type, value, shader_name)
      rescue ArgumentError => e
        raise e if e.message.start_with?("Invalid value for uniform", "Unsupported runtime uniform type")

        raise ArgumentError, invalid_uniform_message(name, type, value, shader_name)
      end

      def normalize_bool(value, name:, shader_name: nil)
        return value if value == true || value == false
        return false if value == 0
        return true if value == 1

        raise ArgumentError, invalid_uniform_message(name, :bool, value, shader_name)
      end

      def normalize_vector(value, vector_size, name:, shader_name: nil)
        unless value.is_a?(Array) && value.length == vector_size
          raise ArgumentError, invalid_vector_message(name, vector_size, value, shader_name)
        end

        value.map { |component| Float(component) }
      end

      private

      def missing_uniform_message(name, shader_name)
        "Missing uniform #{name.inspect}#{shader_suffix(shader_name)}"
      end

      def invalid_uniform_message(name, type, value, shader_name)
        "Invalid value for uniform #{name.inspect}#{shader_suffix(shader_name)}: expected #{type}, got #{value.inspect}"
      end

      def invalid_vector_message(name, vector_size, value, shader_name)
        "Invalid value for uniform #{name.inspect}#{shader_suffix(shader_name)}: expected vec#{vector_size}, got #{value.inspect}"
      end

      def unsupported_runtime_type_message(type, shader_name)
        "Unsupported runtime uniform type #{type.inspect}#{shader_suffix(shader_name)}"
      end

      def shader_suffix(shader_name)
        shader_name ? " in #{shader_name}" : ""
      end
    end
  end
end
