# frozen_string_literal: true

module RLSL
  # DSL context for defining uniform variables
  class UniformContext
    RESERVED_NAMES = %i[resolution u frag_coord].freeze

    attr_reader :uniforms

    def initialize
      @uniforms = {}
    end

    def define_uniform(name, type)
      normalized_name = RLSL.validate_identifier!(name, context: "uniform name").to_sym
      if RESERVED_NAMES.include?(normalized_name)
        raise ArgumentError, "Uniform name #{normalized_name.inspect} is reserved by RLSL"
      end
      if @uniforms.key?(normalized_name)
        raise ArgumentError, "Uniform #{normalized_name.inspect} is already defined"
      end
      generated_sampler_names = @uniforms.filter_map do |uniform_name, uniform_type|
        :"#{uniform_name}_sampler" if uniform_type == :sampler2D
      end
      if generated_sampler_names.include?(normalized_name) ||
         (type == :sampler2D && @uniforms.key?(:"#{normalized_name}_sampler"))
        raise ArgumentError, "Uniform #{normalized_name.inspect} conflicts with a generated sampler name"
      end

      @uniforms[normalized_name] = type
    end

    RLSL::UNIFORM_TYPES.each do |type|
      define_method(type) do |name|
        define_uniform(name, type)
      end
    end
  end
end
