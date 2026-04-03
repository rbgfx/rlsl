# frozen_string_literal: true

module RLSL
  # DSL context for defining uniform variables
  class UniformContext
    attr_reader :uniforms

    def initialize
      @uniforms = {}
    end

    def define_uniform(name, type)
      @uniforms[name] = type
    end

    RLSL::UNIFORM_TYPES.each do |type|
      define_method(type) do |name|
        define_uniform(name, type)
      end
    end
  end
end
