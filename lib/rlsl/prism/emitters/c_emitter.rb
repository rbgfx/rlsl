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
            mod: "rlsl_mod",
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
          if name == :atan && node.args.length == 2
            return emit_named_call("atan2f", node.args, expected_types: node.expected_arg_types)
          end
          if %i[distance cross].include?(name) && vector_type?(node.args.first&.type)
            return emit_named_call("#{node.args.first.type}_#{name}", node.args,
                                   expected_types: node.expected_arg_types)
          end
          if vector_math_call?(name, node)
            return emit_named_call("#{node.args.first.type}_#{name}", node.args,
                                   expected_types: node.expected_arg_types)
          end
          if vector_mix_call?(name, node)
            return emit_named_call("mix_#{vector_suffix(node.args.first.type)}", node.args,
                                   expected_types: node.expected_arg_types)
          end
        end

        def emit_profile_binary_op(node)
          return emit_float_modulo(node) if node.operator == "%" && node.type == :float
          return unless profile.vector_ops.key?(node.operator)

          emit_vector_binary_op(node)
        end

        def emit_unary_op(node)
          if node.operator == "-" && vector_type?(node.operand.type)
            return emit_named_call("#{node.operand.type}_mul_scalar", [node.operand, IR::Literal.new(-1.0, :float)])
          end

          super
        end

        def emit_bool_literal(node)
          node.value ? "1" : "0"
        end

        def emit_field_access(node)
          return super if node.receiver.type == :uniforms

          field = node.field.to_s
          if Builtins.single_component_field?(field)
            component = Builtins::SWIZZLE_COMPONENTS.fetch(field)
            return "#{emit(node.receiver)}.#{%w[x y z w].fetch(component)}"
          end
          return super unless Builtins.swizzle?(field)

          indices = field.each_char.map { |component| Builtins::SWIZZLE_COMPONENTS.fetch(component) }
          "#{node.receiver.type}_swizzle#{indices.length}(#{emit(node.receiver)}, #{indices.join(', ')})"
        end

        def emit_float_operand(node)
          return emit(node) unless node.type == :int

          "(float)(#{emit(node)})"
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
          "rlsl_mod(#{emit_float_operand(node.left)}, #{emit_float_operand(node.right)})"
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
          component_count = node.args.sum { |argument| vector_size(argument.type) || 1 }
          component_count = size if node.args.length == 1 && !vector_type?(node.args.first.type)

          unless component_count == size
            raise TargetCapabilityError,
                  "#{node.name} constructor produces #{component_count} components on C, expected #{size}"
          end

          return "#{node.name}_splat(#{emit(node.args.first)})" if node.args.length == 1 && !vector_type?(node.args.first.type)
          return emit_named_call("#{node.name}_new", node.args) unless node.args.any? { |argument| vector_type?(argument.type) }

          signature = node.args.map { |argument| vector_type?(argument.type) ? argument.type : :float }.join("_")
          emit_named_call("#{node.name}_from_#{signature}", node.args)
        end

        def vector_size(type)
          { vec2: 2, vec3: 3, vec4: 4 }[type]
        end
      end
    end
  end
end
