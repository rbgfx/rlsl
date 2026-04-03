# frozen_string_literal: true

begin
  require "metaco"
  METACO_AVAILABLE = true
rescue LoadError
  METACO_AVAILABLE = false
end

module RLSL
  module MSL
    class Shader
      attr_reader :name, :msl_source

      def initialize(name, uniforms, msl_source)
        @name = name
        @uniform_types = uniforms
        @uniform_names = uniforms.keys
        @msl_source = msl_source
        @compiled_handles = {}
      end

      def metal?
        true
      end

      def render_metal(handle, width, height, uniforms = {})
        unless METACO_AVAILABLE
          raise LoadError, "metaco gem is required for Metal rendering. Install it with: gem install metaco"
        end

        unless @compiled_handles[handle]
          Metaco.compile_compute_shader(handle, @msl_source)
          @compiled_handles[handle] = true
        end

        uniform_data = pack_uniforms(uniforms, width, height)

        Metaco.dispatch_compute(handle, uniform_data)
        Metaco.present_compute(handle)
      end

      private

      def pack_uniforms(uniforms, width, height)
        normalized_uniforms = UniformTypes.normalize_values(@uniform_types, uniforms, shader_name: @name)
        data = [width.to_f, height.to_f].pack("ff")
        current_offset = 8

        @uniform_names.each do |name|
          value = normalized_uniforms[name]
          spec = UniformTypes.metal_spec(@uniform_types[name])
          alignment = spec.metal_alignment

          padding_needed = (alignment - (current_offset % alignment)) % alignment
          data += "\x00" * padding_needed
          current_offset += padding_needed

          data += pack_uniform_value(spec, value)
          current_offset += spec.metal_size
        end

        data.ljust(256, "\x00")
      end

      def pack_uniform_value(spec, value)
        case spec.wrapper_kind
        when :float
          [value.to_f].pack("f")
        when :int
          [value.to_i].pack("l")
        when :bool
          [value ? 1 : 0].pack("l")
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
          components.pack("ff")
        when 3
          (components + [0.0]).pack("ffff")
        when 4
          components.pack("ffff")
        else
          raise ArgumentError, "Unsupported vector size: #{vector_size}"
        end
      end
    end
  end
end
