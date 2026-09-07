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
            element_type_symbol = TypeShapes.element_type(node.type) || :float
            element_type = type_name(element_type_symbol)
            size = node.initializer.elements.length
            values = node.initializer.elements.map do |element|
              emit_typed_argument(element, element_type_symbol)
            end.join(", ")
            return "var #{node.name}: array<#{element_type}, #{size}> = array<#{element_type}, #{size}>(#{values})"
          end

          value = emit(node.initializer)
          binding = node.mutable ? "var" : "let"
          "#{binding} #{node.name}: #{type} = #{value}"
        end

        def emit_for_loop(node)
          variable = node.variable
          counter = loop_variable_mutated?(node) ? next_temporary_name("i") : variable
          start_val = emit(node.range_start)
          end_val = emit(node.range_end)
          body = emit_indented_block(node.body)
          body = "#{indent}  var #{variable}: i32 = #{counter};\n#{body}" if counter != variable

          comparison = node.exclude_end ? "<" : "<="
          return "for (var #{counter}: i32 = #{start_val}; #{counter} #{comparison} #{end_val}; #{counter}++) {\n#{body}#{indent}}" if node.range_end.is_a?(IR::Literal)

          bound = next_temporary_name("end")
          "let #{bound}: i32 = #{end_val};\n#{indent}for (var #{counter}: i32 = #{start_val}; #{counter} #{comparison} #{bound}; #{counter}++) {\n#{body}#{indent}}"
        end

        def emit_ternary(_node)
          raise TargetCapabilityError,
                "WGSL conditional expressions cannot be emitted without eager branch evaluation"
        end

        def emit_binary_op(node)
          if node.operator == "%" && node.type == :float
            return "rlsl_mod(#{emit_float_operand(node.left)}, #{emit_float_operand(node.right)})"
          end

          super
        end

        def emit_func_call(node)
          if node.name.to_sym == :mod
            args = node.args.map { |argument| emit_float_operand(argument) }
            return "rlsl_mod(#{args.join(', ')})"
          end
          if node.name.to_sym == :atan && node.args.length == 2
            return emit_named_call("atan2", node.args, expected_types: node.expected_arg_types)
          end

          super
        end

        def emit_function_definition(node)
          name = node.name
          mutable_params = mutated_parameters(node)
          initializers = []
          sampler_params = {}
          params = node.params.flat_map do |param|
            type = node.param_types[param] || :float
            if type == :sampler2D
              if mutable_params.include?(param)
                raise TargetCapabilityError, "WGSL texture parameter #{param} cannot be reassigned"
              end

              sampler_params[param] = next_temporary_name("sampler")
              ["#{param}: #{type_name(type)}", "#{sampler_params[param]}: sampler"]
            elsif mutable_params.include?(param)
              argument = next_temporary_name("param")
              initializers << "#{indent}  var #{param}: #{type_name(type)} = #{argument};\n"
              ["#{argument}: #{type_name(type)}"]
            else
              ["#{param}: #{type_name(type)}"]
            end
          end.join(", ")

          if node.return_type.is_a?(Array)
            struct_def = emit_result_struct(name, node.return_type)
            body = with_return_struct_name("#{name}_result") do
              with_sampler_parameters(sampler_params) do
                with_return_type(node.return_type) { emit_indented_block(node.body, needs_return: true) }
              end
            end

            "#{struct_def}fn #{name}(#{params}) -> #{name}_result {\n#{initializers.join}#{body}#{indent}}\n"
          else
            return_type = type_name(node.return_type || :float)
            body = with_sampler_parameters(sampler_params) do
              with_return_type(node.return_type) { emit_indented_block(node.body, needs_return: true) }
            end

            "fn #{name}(#{params}) -> #{return_type} {\n#{initializers.join}#{body}#{indent}}\n"
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
            element_type_symbol = node.element_type || TypeShapes.element_type(node.initializer.type) || :float
            element_type = type_name(element_type_symbol)
            size = node.array_size || node.initializer.elements.length
            values = node.initializer.elements.map do |element|
              emit_typed_argument(element, element_type_symbol)
            end.join(", ")
            prefix = node.is_const ? "const" : "var<private>"
            return "#{prefix} #{node.name}: array<#{element_type}, #{size}> = array<#{element_type}, #{size}>(#{values})"
          end

          prefix = node.is_const ? "const" : "var<private>"
          "#{prefix} #{node.name}: #{type_name(node.type || :float)} = #{emit(node.initializer)}"
        end

        def emit_field_access(node)
          return node.field.to_s if node.receiver.type == :uniforms && node.type == :sampler2D

          code = super
          return "(#{code} != 0)" if node.receiver.type == :uniforms && node.type == :bool

          code
        end

        def emit_texture_call(name, node)
          return unless profile.texture_functions.key?(name) && node.args.length >= 2

          texture = emit(node.args[0])
          sampler = sampler_name(node.args[0], texture)
          uv = emit(node.args[1])
          lod = node.args[2] ? emit_typed_argument(node.args[2], :float) : "0.0"
          "textureSampleLevel(#{texture}, #{sampler}, #{uv}, #{lod})"
        end

        def emit_named_call(name, args, receiver: nil, expected_types: [])
          arguments = receiver ? [receiver, *args] : args
          rendered = arguments.each_with_index.flat_map do |argument, index|
            if expected_types[index] == :sampler2D
              texture = emit(argument)
              [texture, sampler_name(argument, texture)]
            else
              [emit_typed_argument(argument, expected_types[index])]
            end
          end
          "#{name}(#{rendered.join(', ')})"
        end

        def emit_multiple_assignment_target(target, declaration)
          declaration ? "var #{target.name}: #{type_name(target.type || :float)}" : target.name.to_s
        end

        def emit_temporary_declaration(type, name, value)
          "let #{name}: #{type} = #{value}"
        end

        def emit_tuple_value(node)
          expected_types = Array(current_return_type)
          elements = node.elements.each_with_index.map do |element, index|
            emit_typed_argument(element, expected_types[index])
          end.join(", ")
          "#{current_return_struct_name}(#{elements})"
        end

        private

        def mutated_parameters(node)
          parameters = node.params.to_set
          IR::Traversal.each(node.body).each_with_object(Set.new) do |current, names|
            case current
            when IR::Assignment
              names.add(current.target.name) if current.target.is_a?(IR::VarRef) && parameters.include?(current.target.name)
            when IR::MultipleAssignment
              current.targets.each { |target| names.add(target.name) if parameters.include?(target.name) }
            end
          end
        end

        def with_sampler_parameters(parameters)
          previous = @sampler_parameters
          @sampler_parameters = parameters
          yield
        ensure
          @sampler_parameters = previous
        end

        def sampler_name(argument, texture)
          return @sampler_parameters[argument.name] if argument.is_a?(IR::VarRef) && @sampler_parameters&.key?(argument.name)

          "#{texture}_sampler"
        end
      end
    end
  end
end
