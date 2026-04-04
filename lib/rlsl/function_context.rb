# frozen_string_literal: true

module RLSL
  class FunctionContext
    attr_reader :functions

    def initialize
      @functions = {}
    end

    # Full form: specify return type and parameter types
    # @example
    #   define :path_point, returns: :vec3, params: { z: :float }
    #   define :noise_a, returns: :float, params: { f: :float, h: :float, k: :float, p: :vec3 }
    def define(name, returns:, params: {})
      @functions[name.to_sym] = {
        returns: validate_type!(returns),
        params: normalize_params(params)
      }
    end

    UniformTypes.function_shorthand_types.each do |type|
      define_method(type) do |*names|
        register_shorthand_functions(type, *names)
      end
    end

    private

    def register_shorthand_functions(type, *names)
      validated_type = validate_type!(type)
      names.each do |name|
        @functions[name.to_sym] = { returns: validated_type }
      end
    end

    def normalize_params(params)
      params.each_with_object({}) do |(name, type), normalized|
        normalized[name.to_sym] = validate_type!(type)
      end
    end

    def validate_type!(type)
      if type.is_a?(Array)
        return type.map { |element_type| validate_type!(element_type) }
      end

      UniformTypes.fetch(type)
      type
    end
  end
end
