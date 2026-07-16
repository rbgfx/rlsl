# frozen_string_literal: true

module RLSL
  module MSL
    class UniformBufferPacker
      def initialize(shader_name, uniform_types, uniform_names)
        @shader_name = shader_name
        @uniform_types = uniform_types
        @uniform_names = uniform_names
      end

      def pack(width, height, uniforms)
        normalized_uniforms = UniformTypes.normalize_values(@uniform_types, uniforms, shader_name: @shader_name)
        data = [width.to_f, height.to_f].pack("e2")
        current_offset = 8

        @uniform_names.each do |name|
          value = normalized_uniforms[name]
          spec = UniformTypes.metal_spec(@uniform_types[name])
          current_offset, data = append_padding(data, current_offset, spec.metal_alignment)
          data << pack_uniform_value(spec, value)
          current_offset += spec.metal_size
        end

        if data.bytesize > 256
          raise ArgumentError, "Metal uniform buffer exceeds 256 bytes (#{data.bytesize} bytes)"
        end

        data.ljust(256, "\x00")
      end

      private

      def append_padding(data, current_offset, alignment)
        padding_needed = (alignment - (current_offset % alignment)) % alignment
        return [current_offset, data] if padding_needed.zero?

        [current_offset + padding_needed, data + ("\x00" * padding_needed)]
      end

      def pack_uniform_value(spec, value)
        case spec.wrapper_kind
        when :float
          [value.to_f].pack("e")
        when :int
          [value.to_i].pack("l<")
        when :bool
          [value ? 1 : 0].pack("l<")
        when :vector
          pack_vector_uniform(spec.vector_size, value)
        else
          raise ArgumentError, "Unsupported Metal uniform type: #{spec.c_type}"
        end
      end

      def pack_vector_uniform(vector_size, value)
        components = Array(value).map(&:to_f)

        case vector_size
        when 2
          components.pack("e2")
        when 3
          (components + [0.0]).pack("e4")
        when 4
          components.pack("e4")
        else
          raise ArgumentError, "Unsupported vector size: #{vector_size}"
        end
      end
    end
  end
end
