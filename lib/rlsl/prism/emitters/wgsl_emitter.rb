# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class WGSLEmitter < TargetEmitter
        PROFILE = TargetProfile.new(
          type_map: {
            float: "f32",
            int: "i32",
            bool: "bool",
            vec2: "vec2<f32>",
            vec3: "vec3<f32>",
            vec4: "vec4<f32>",
            mat2: "mat2x2<f32>",
            mat3: "mat3x3<f32>",
            mat4: "mat4x4<f32>",
            sampler2D: "texture_2d<f32>"
          },
          vector_constructors: {
            vec2: "vec2<f32>",
            vec3: "vec3<f32>",
            vec4: "vec4<f32>"
          },
          matrix_constructors: {
            mat2: "mat2x2<f32>",
            mat3: "mat3x3<f32>",
            mat4: "mat4x4<f32>"
          },
          texture_functions: {
            texture2D: "textureSample",
            texture: "textureSample",
            textureLod: "textureSampleLevel"
          },
          default_type_name: "f32"
        ).freeze

        TYPE_MAP = PROFILE.type_map
        VECTOR_CONSTRUCTORS = PROFILE.vector_constructors
        MATRIX_CONSTRUCTORS = PROFILE.matrix_constructors
        TEXTURE_FUNCTIONS = PROFILE.texture_functions
        protected

        def emit_var_decl(node)
          type = type_name(node.type || :float)
          value = emit(node.initializer)
          "let #{node.name}: #{type} = #{value}"
        end

        def emit_for_loop(node)
          var = node.variable
          start_val = emit(node.range_start)
          end_val = emit(node.range_end)
          body = emit_indented_block(node.body)

          "for (var #{var}: i32 = #{start_val}; #{var} < #{end_val}; #{var}++) {\n#{body}#{indent}}"
        end

        def emit_ternary(node)
          condition = emit(node.condition)
          then_expr = emit(node.then_expr)
          else_expr = emit(node.else_expr)
          "select(#{else_expr}, #{then_expr}, #{condition})"
        end

        def emit_function_definition(node)
          name = node.name
          params = node.params.map do |param|
            param_type = type_name(node.param_types[param] || :float)
            "#{param}: #{param_type}"
          end.join(", ")

          if node.return_type.is_a?(Array)
            @current_return_struct_name = "#{name}_result"
            struct_def = emit_result_struct(name, node.return_type)
            body = emit_indented_block(node.body, needs_return: true)
            @current_return_struct_name = nil

            "#{struct_def}fn #{name}(#{params}) -> #{name}_result {\n#{body}\n#{indent}}\n"
          else
            return_type = type_name(node.return_type || :float)
            body = emit_indented_block(node.body, needs_return: true)

            "fn #{name}(#{params}) -> #{return_type} {\n#{body}\n#{indent}}\n"
          end
        end

        def emit_result_struct(func_name, types)
          fields = types.each_with_index.map do |type, index|
            "#{indent}v#{index}: #{type_name(type)},"
          end.join("\n")
          "struct #{func_name}_result {\n#{fields}\n};\n"
        end
      end
    end
  end
end
