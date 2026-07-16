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
            sign: "sign_f",
            step: "step_f",
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

        protected

        def format_number(value, type: nil)
          formatted = super(value, type: type)
          return formatted if type == :int || value.is_a?(Integer)

          "#{formatted}f"
        end

        def emit_profile_func_call(node)
          name = node.name.to_sym
          return emit_c_vector_constructor(node) if vector_type?(name)
          return emit_named_call("atan2f", node.args) if name == :atan && node.args.length == 2
          if %i[distance cross].include?(name) && vector_type?(node.args.first&.type)
            return emit_named_call("#{node.args.first.type}_#{name}", node.args)
          end
          return emit_named_call("#{node.args.first.type}_#{name}", node.args) if vector_math_call?(name, node)
          return emit_named_call("mix_#{vector_suffix(node.args.first.type)}", node.args) if vector_mix_call?(name, node)
        end

        def emit_profile_binary_op(node)
          return emit_float_modulo(node) if node.operator == "%" && node.type == :float
          return unless profile.vector_ops.key?(node.operator)

          emit_vector_binary_op(node)
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

        def vector_suffix(type)
          { vec2: "v2", vec3: "v3", vec4: "v4" }.fetch(type)
        end

        def emit_float_modulo(node)
          emit_named_call("fmodf", [node.left, node.right])
        end

        def emit_vector_binary_op(node)
          left_vector = vector_type?(node.left.type)
          right_vector = vector_type?(node.right.type)
          return unless left_vector || right_vector

          vector_type = left_vector ? node.left.type : node.right.type
          operation = profile.vector_ops.fetch(node.operator)

          if left_vector && right_vector
            suffix = %w[* /].include?(node.operator) ? "_components" : ""
            return emit_named_call("#{vector_type}_#{operation}#{suffix}", [node.left, node.right])
          end

          if left_vector
            return emit_named_call("#{vector_type}_#{operation}_scalar", [node.left, node.right])
          end

          emit_named_call("#{vector_type}_scalar_#{operation}", [node.left, node.right])
        end

        def emit_c_vector_constructor(node)
          size = { vec2: 2, vec3: 3, vec4: 4 }.fetch(node.name.to_sym)
          components = node.args.flat_map do |argument|
            if vector_type?(argument.type)
              %w[x y z w].first({ vec2: 2, vec3: 3, vec4: 4 }.fetch(argument.type)).map do |field|
                "#{emit(argument)}.#{field}"
              end
            else
              emit(argument)
            end
          end
          components *= size if components.length == 1

          unless components.length == size
            raise TargetCapabilityError,
                  "#{node.name} constructor produces #{components.length} components on C, expected #{size}"
          end

          "#{node.name}_new(#{components.join(', ')})"
        end
      end
    end
  end
end
