# frozen_string_literal: true

module RLSL
  class RuntimeShader
    attr_reader :name, :uniform_types, :uniform_names

    def initialize(name, uniforms)
      @name = name
      @uniform_types = normalize_uniform_types(uniforms)
      @uniform_names = @uniform_types.keys
    end

    def metal?
      false
    end

    def render(*)
      raise NotImplementedError, "Subclasses must implement render"
    end

    protected

    def normalized_uniforms(uniforms)
      UniformTypes.normalize_values(@uniform_types, uniforms, shader_name: @name)
    end

    def ordered_uniform_values(uniforms)
      normalized = normalized_uniforms(uniforms)
      @uniform_names.map { |name| normalized[name] }
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
