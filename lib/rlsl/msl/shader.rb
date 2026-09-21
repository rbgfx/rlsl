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
        value_uniform_types = @uniform_types.reject { |_name, type| type == :sampler2D }
        @uniform_buffer_packer = UniformBufferPacker.new(@name, value_uniform_types, value_uniform_types.keys)
      end

      def metal?
        true
      end

      def render(handle, width, height, uniforms = {})
        render_metal(handle, width, height, uniforms)
      end

      def prepare(handle)
        unless METACO_AVAILABLE
          raise LoadError, "metaco gem is required for Metal rendering. Install it with: gem install metaco"
        end

        unless @compiled_handles[handle]
          Metaco.compile_compute_shader(handle, @msl_source)
          @compiled_handles[handle] = true
          @compiled_handles.shift while @compiled_handles.length > COMPILED_HANDLE_CACHE_LIMIT
        end
        self
      end

      def render_metal(handle, width, height, uniforms = {}, textures: {})
        prepare(handle)

        uniform_data = pack_uniforms(uniforms, width, height)

        sampler_names = @uniform_types.filter_map { |name, type| name if type == :sampler2D }
        sampler_names.each do |name|
          texture = textures[name] || textures[name.to_s]
          raise ArgumentError, "missing texture uniform: #{name}" unless texture
          unless Metaco.respond_to?(:bind_compute_texture)
            raise LoadError, "metaco texture support is required for sampler2D uniforms"
          end
          Metaco.bind_compute_texture(handle, sampler_names.index(name), texture)
        end

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
