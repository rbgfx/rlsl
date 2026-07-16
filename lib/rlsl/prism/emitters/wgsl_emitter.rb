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

        protected

        def emit_var_decl(node)
          type = type_name(node.type || :float)
          return "var #{node.name}: #{type}" unless node.initializer

          if node.initializer.is_a?(IR::ArrayLiteral)
            element_type = type_name(node.initializer.elements.first&.type || :float)
            size = node.initializer.elements.length
            values = node.initializer.elements.map { |element| emit(element) }.join(", ")
            return "var #{node.name}: array<#{element_type}, #{size}> = array<#{element_type}, #{size}>(#{values})"
          end

          value = emit(node.initializer)
          binding = node.mutable ? "var" : "let"
          "#{binding} #{node.name}: #{type} = #{value}"
        end

        def emit_for_loop(node)
          var = node.variable
          start_val = emit(node.range_start)
          end_val = emit(node.range_end)
          body = emit_indented_block(node.body)

          comparison = node.exclude_end ? "<" : "<="
          "for (var #{var}: i32 = #{start_val}; #{var} #{comparison} #{end_val}; #{var}++) {\n#{body}#{indent}}"
        end

        def emit_ternary(node)
          raise TargetCapabilityError,
                "WGSL conditional expressions cannot be emitted without eager branch evaluation"
        end

        def emit_function_definition(node)
          name = node.name
          params = node.params.map do |param|
            param_type = type_name(node.param_types[param] || :float)
            "#{param}: #{param_type}"
          end.join(", ")

          if node.return_type.is_a?(Array)
            struct_def = emit_result_struct(name, node.return_type)
            body = with_return_struct_name("#{name}_result") do
              emit_indented_block(node.body, needs_return: true)
            end

            "#{struct_def}fn #{name}(#{params}) -> #{name}_result {\n#{body}#{indent}}\n"
          else
            return_type = type_name(node.return_type || :float)
            body = emit_indented_block(node.body, needs_return: true)

            "fn #{name}(#{params}) -> #{return_type} {\n#{body}#{indent}}\n"
          end
        end

        def emit_result_struct(func_name, types)
          fields = types.each_with_index.map do |type, index|
            "#{indent}v#{index}: #{type_name(type)},"
          end.join("\n")
          "struct #{func_name}_result {\n#{fields}\n}\n"
        end

        def emit_hoisted_declarations(node)
          node.hoisted_variables.map do |name, type|
            "#{indent}var #{name}: #{type_name(type || :float)};\n"
          end.join
        end

        def emit_global_decl(node)
          if node.initializer.is_a?(IR::ArrayLiteral)
            element_type = type_name(node.element_type || node.initializer.elements.first&.type || :float)
            size = node.array_size || node.initializer.elements.length
            values = node.initializer.elements.map { |element| emit(element) }.join(", ")
            prefix = node.is_const ? "const" : "var<private>"
            return "#{prefix} #{node.name}: array<#{element_type}, #{size}> = array<#{element_type}, #{size}>(#{values})"
          end

          prefix = node.is_const ? "const" : "var<private>"
          "#{prefix} #{node.name}: #{type_name(node.type || :float)} = #{emit(node.initializer)}"
        end

        def emit_field_access(node)
          code = super
          return "(#{code} != 0)" if node.receiver.type == :uniforms && node.type == :bool

          code
        end
      end
    end
  end
end
