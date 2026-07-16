# frozen_string_literal: true

module RLSL
  module MSL
    begin
      require "metaco"
      METACO_AVAILABLE = true
    rescue LoadError
      METACO_AVAILABLE = false
    end

    class Shader < RuntimeShader
      COMPILED_HANDLE_CACHE_LIMIT = 64
      attr_reader :name, :msl_source

      def initialize(name, uniforms, msl_source)
        super(name, uniforms)
        @msl_source = msl_source
        @compiled_handles = {}
        @uniform_buffer_packer = UniformBufferPacker.new(@name, @uniform_types, @uniform_names)
      end

      def metal?
        true
      end

      def render(handle, width, height, uniforms = {})
        render_metal(handle, width, height, uniforms)
      end

      def render_metal(handle, width, height, uniforms = {})
        unless METACO_AVAILABLE
          raise LoadError, "metaco gem is required for Metal rendering. Install it with: gem install metaco"
        end

        unless @compiled_handles[handle]
          Metaco.compile_compute_shader(handle, @msl_source)
          @compiled_handles[handle] = true
          @compiled_handles.shift while @compiled_handles.length > COMPILED_HANDLE_CACHE_LIMIT
        end

        uniform_data = pack_uniforms(uniforms, width, height)

        Metaco.dispatch_compute(handle, uniform_data)
        Metaco.present_compute(handle)
      end

      private

      def pack_uniforms(uniforms, width, height)
        @uniform_buffer_packer.pack(width, height, uniforms)
      end
    end
  end
end
