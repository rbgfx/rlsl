# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class GLSLEmitter < TargetEmitter
        PROFILE = TargetProfile.new(
          type_map: {
            float: "float",
            int: "int",
            bool: "bool",
            vec2: "vec2",
            vec3: "vec3",
            vec4: "vec4",
            mat2: "mat2",
            mat3: "mat3",
            mat4: "mat4",
            sampler2D: "sampler2D"
          },
          vector_constructors: {
            vec2: "vec2",
            vec3: "vec3",
            vec4: "vec4"
          },
          matrix_constructors: {
            mat2: "mat2",
            mat3: "mat3",
            mat4: "mat4"
          },
          texture_functions: {
            texture2D: "texture2D",
            texture: "texture",
            textureLod: "textureLod"
          }
        ).freeze

        protected

        def function_qualifier
          ""
        end

        def emit_binary_op(node)
          if node.operator == "%" && (node.left.type != :int || node.right.type != :int)
            return "mod(#{emit(node.left)}, #{emit(node.right)})"
          end

          super
        end

        def emit_result_struct(func_name, types)
          fields = types.each_with_index.map { |type, index| "#{type_name(type)} v#{index};" }.join(" ")
          "struct #{func_name}_result { #{fields} };\n"
        end

        def emit_field_access(node)
          return node.field.to_s if node.receiver.type == :uniforms && node.type == :sampler2D

          super
        end

        def emit_texture_call(name, node)
          return unless profile.texture_functions.key?(name) && node.args.length >= 2

          args = [node.args[0], node.args[1], node.args[2] || IR::Literal.new(0.0, :float)]
          emit_named_call("textureLod", args)
        end

        def emit_func_call(node)
          return emit_named_call("atan", node.args) if node.name.to_sym == :atan2

          super
        end

        def emit_tuple_value(node)
          elements = node.elements.map { |element| emit(element) }.join(", ")
          "#{current_return_struct_name}(#{elements})"
        end
      end
    end
  end
end
