# frozen_string_literal: true

module RLSL
  class CompiledShader
    def initialize(name, ext_name, uniforms)
      @name = name
      @ext_name = ext_name
      @uniform_types = normalize_uniform_types(uniforms)
      @uniform_names = @uniform_types.keys
      @render_method = RLSL::CompiledShaders.method("#{name}_render")
    end

    def metal?
      false
    end

    def render(buffer, width, height, uniforms = {})
      normalized_uniforms = UniformTypes.normalize_values(@uniform_types, uniforms, shader_name: @name)
      args = [buffer, width, height]
      @uniform_names.each do |name|
        args << normalized_uniforms[name]
      end
      @render_method.call(*args)
    end

    private

    def normalize_uniform_types(uniforms)
      case uniforms
      when Hash
        uniforms.each_with_object({}) do |(name, type), normalized|
          normalized[name.to_sym] = type
        end
      else
        Array(uniforms).each_with_object({}) do |name, normalized|
          normalized[name.to_sym] = nil
        end
      end
    end
  end
end
