# frozen_string_literal: true

module RLSL
  class CompiledShader < RuntimeShader
    def initialize(name, ext_name, uniforms)
      super(name, uniforms)
      @ext_name = ext_name
      @render_method = RLSL::CompiledShaders.method("#{name}_render")
    end

    def render(buffer, width, height, uniforms = {})
      args = [buffer, width, height] + ordered_uniform_values(uniforms)
      @render_method.call(*args)
    end
  end
end
