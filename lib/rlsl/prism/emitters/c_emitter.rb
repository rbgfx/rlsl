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
          },
          call_resolver: :emit_profile_func_call,
          binary_op_resolver: :emit_profile_binary_op
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

        def emit_profile_func_call(node)
          name = node.name.to_sym
          return emit_named_call("#{node.args.first.type}_#{name}", node.args) if vector_math_call?(name, node)
          return emit_named_call("mix_v3", node.args) if vector_mix_call?(name, node)
        end

        def emit_profile_binary_op(node)
          return unless vector_type?(node.left.type) && profile.vector_ops.key?(node.operator)

          emit_named_call("#{node.left.type}_#{profile.vector_ops[node.operator]}", [node.left, node.right])
        end

        def emit_bool_literal(node)
          node.value ? "1" : "0"
        end

        private

        def vector_math_call?(name, node)
          %i[length normalize dot].include?(name) && vector_type?(node.args.first&.type)
        end

        def vector_mix_call?(name, node)
          name == :mix && vector_type?(node.args.first&.type)
        end

        def vector_type?(type)
          %i[vec2 vec3 vec4].include?(type)
        end
      end
    end
  end
end
