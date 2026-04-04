# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class CEmitter < TargetEmitter
        PROFILE = TargetProfile.new(
          type_map: {
            float: "float",
            int: "int",
            bool: "int",
            vec2: "vec2",
            vec3: "vec3",
            vec4: "vec4",
            mat2: "mat2",
            mat3: "mat3",
            mat4: "mat4",
            sampler2D: "sampler2D"
          },
          vector_constructors: {
            vec2: "vec2_new",
            vec3: "vec3_new",
            vec4: "vec4_new"
          },
          matrix_constructors: {
            mat2: "mat2_new",
            mat3: "mat3_new",
            mat4: "mat4_new"
          },
          texture_functions: {
            texture2D: "texture_sample",
            texture: "texture_sample",
            textureLod: "texture_sample_lod"
          },
          math_functions: {
            sin: "sinf",
            cos: "cosf",
            tan: "tanf",
            asin: "asinf",
            acos: "acosf",
            atan: "atanf",
            atan2: "atan2f",
            sqrt: "sqrtf",
            pow: "powf",
            exp: "expf",
            log: "logf",
            abs: "fabsf",
            floor: "floorf",
            ceil: "ceilf",
            min: "fminf",
            max: "fmaxf",
            fract: "fract",
            mod: "fmodf",
            clamp: "clamp_f",
            mix: "mix_f",
            smoothstep: "smoothstep",
            length: "vec_length",
            normalize: "vec_normalize",
            dot: "vec_dot"
          },
          vector_ops: {
            "+" => "add",
            "-" => "sub",
            "*" => "mul",
            "/" => "div"
          }
        ).freeze

        TYPE_MAP = PROFILE.type_map
        VECTOR_CONSTRUCTORS = PROFILE.vector_constructors
        MATRIX_CONSTRUCTORS = PROFILE.matrix_constructors
        TEXTURE_FUNCTIONS = PROFILE.texture_functions
        VECTOR_OPS = PROFILE.vector_ops
        MATH_FUNCTIONS = PROFILE.math_functions

        protected

        def format_number(value)
          formatted = super(value)
          "#{formatted}f"
        end

        def emit_func_call(node)
          name = node.name.to_sym

          if VECTOR_CONSTRUCTORS.key?(name)
            args = node.args.map { |arg| emit(arg) }.join(", ")
            return "#{VECTOR_CONSTRUCTORS[name]}(#{args})"
          end

          if MATRIX_CONSTRUCTORS.key?(name)
            args = node.args.map { |arg| emit(arg) }.join(", ")
            return "#{MATRIX_CONSTRUCTORS[name]}(#{args})"
          end

          if TEXTURE_FUNCTIONS.key?(name)
            args = node.args.map { |arg| emit(arg) }.join(", ")
            return "#{TEXTURE_FUNCTIONS[name]}(#{args})"
          end

          if %i[length normalize dot].include?(name) && node.args.first&.type
            vec_type = node.args.first.type
            if %i[vec2 vec3 vec4].include?(vec_type)
              func_name = "#{vec_type}_#{name}"
              args = node.args.map { |arg| emit(arg) }.join(", ")
              return "#{func_name}(#{args})"
            end
          end

          if profile.math_functions.key?(name)
            func_name = profile.math_functions[name]

            if name == :mix && node.args.first&.type
              first_type = node.args.first.type
              if %i[vec2 vec3 vec4].include?(first_type)
                func_name = "mix_v3"
              end
            end

            args = node.args.map { |arg| emit(arg) }.join(", ")
            return "#{func_name}(#{args})"
          end

          super
        end

        def emit_binary_op(node)
          left_type = node.left.type
          op = node.operator

          if vector_type?(left_type) && profile.vector_ops.key?(op)
            vec_func = "#{left_type}_#{profile.vector_ops[op]}"
            left = emit(node.left)
            right = emit(node.right)
            return "#{vec_func}(#{left}, #{right})"
          end

          super
        end

        def emit_bool_literal(node)
          node.value ? "1" : "0"
        end

        private

        def vector_type?(type)
          %i[vec2 vec3 vec4].include?(type)
        end
      end
    end
  end
end
