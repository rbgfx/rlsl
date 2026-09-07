# frozen_string_literal: true

module RLSL
  module Prism
    module Builtins
      module FunctionRegistry
        ALL_TARGETS = %i[c glsl wgsl msl].freeze
        META_TYPES = %i[any same first second third].freeze

        FUNCTIONS = {
          vec2: { args: %i[any any], returns: :vec2, variadic: true, min_args: 1 },
          vec3: { args: %i[any any any], returns: :vec3, variadic: true, min_args: 1 },
          vec4: { args: %i[any any any any], returns: :vec4, variadic: true, min_args: 1 },

          mat2: { args: %i[any any any any], returns: :mat2, variadic: true, min_args: 1, targets: %i[glsl wgsl msl] },
          mat3: { args: %i[any any any any any any any any any], returns: :mat3, variadic: true, min_args: 1, targets: %i[glsl wgsl msl] },
          mat4: { args: %i[any any any any any any any any any any any any any any any any], returns: :mat4, variadic: true, min_args: 1, targets: %i[glsl wgsl msl] },

          sin: { args: [:float], returns: :float },
          cos: { args: [:float], returns: :float },
          tan: { args: [:float], returns: :float },
          asin: { args: [:float], returns: :float },
          acos: { args: [:float], returns: :float },
          atan: { args: %i[float float], returns: :float, variadic: true, min_args: 1 },
          atan2: { args: %i[float float], returns: :float },

          pow: { args: %i[float float], returns: :float },
          exp: { args: [:float], returns: :float },
          log: { args: [:float], returns: :float },
          sqrt: { args: [:any], returns: :same },

          abs: { args: [:any], returns: :same },
          sign: { args: [:any], returns: :same },
          floor: { args: [:any], returns: :same },
          ceil: { args: [:any], returns: :same },
          fract: { args: [:any], returns: :same },
          mod: { args: %i[float float], returns: :float },
          min: { args: %i[any any], returns: :first },
          max: { args: %i[any any], returns: :first },
          clamp: { args: %i[any any any], returns: :first },
          mix: { args: %i[any any float], returns: :first },
          step: { args: %i[float any], returns: :second },
          smoothstep: { args: %i[float float any], returns: :third },

          length: { args: [:any], returns: :float },
          distance: { args: %i[any any], returns: :float },
          dot: { args: %i[any any], returns: :float },
          cross: { args: %i[vec3 vec3], returns: :vec3 },
          normalize: { args: [:any], returns: :same },
          reflect: { args: %i[any any], returns: :first },
          refract: { args: %i[any any float], returns: :first },

          hash21: { args: [:vec2], returns: :float, targets: [:c] },
          hash22: { args: [:vec2], returns: :vec2, targets: [:c] },

          lessThan: { args: %i[any any], returns: :bool, targets: [] },
          lessThanEqual: { args: %i[any any], returns: :bool, targets: [] },
          greaterThan: { args: %i[any any], returns: :bool, targets: [] },
          greaterThanEqual: { args: %i[any any], returns: :bool, targets: [] },
          equal: { args: %i[any any], returns: :bool, targets: [] },
          notEqual: { args: %i[any any], returns: :bool, targets: [] },

          inverse: { args: [:any], returns: :same, targets: %i[glsl wgsl msl] },
          transpose: { args: [:any], returns: :same, targets: %i[glsl wgsl msl] },
          determinant: { args: [:any], returns: :float, targets: %i[glsl wgsl msl] },

          texture2D: { args: %i[sampler2D vec2], returns: :vec4, targets: %i[glsl wgsl msl] },
          texture: { args: %i[sampler2D vec2], returns: :vec4, targets: %i[glsl wgsl msl] },
          textureLod: { args: %i[sampler2D vec2 float], returns: :vec4, targets: %i[glsl wgsl msl] }
        }.freeze

        module_function

        def function?(name)
          FUNCTIONS.key?(name.to_sym)
        end

        def function_signature(name)
          FUNCTIONS[name.to_sym]
        end

        def supported_on_target?(name, target)
          signature = function_signature(name)
          return false unless signature

          Array(signature[:targets] || ALL_TARGETS).include?(target.to_sym)
        end

        def explicit_types(name)
          signature = function_signature(name)
          return [] unless signature

          ([signature[:returns]] + Array(signature[:args])).filter_map do |type|
            type if explicit_type?(type)
          end.uniq
        end

        def resolve_return_type(rule, arg_types)
          case rule
          when :same then arg_types.first
          when :first then arg_types.first
          when :second then arg_types[1]
          when :third then arg_types[2]
          when Symbol then rule
          end
        end

        def explicit_type?(type)
          type.is_a?(Symbol) && !META_TYPES.include?(type)
        end
      end
    end
  end
end
