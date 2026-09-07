# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class BaseEmitter
        module DefinitionEmission
          def emit_function_definition(node)
            name = node.name
            params = node.params.map do |param|
              "#{type_name(node.param_types[param] || :float)} #{param}"
            end.join(", ")

            if node.return_type.is_a?(Array)
              struct_def = emit_result_struct(name, node.return_type)
              body = with_return_struct_name("#{name}_result") do
                emit_indented_block(node.body, needs_return: true)
              end
              "#{struct_def}#{function_qualifier}#{name}_result #{name}(#{params}) {\n#{body}#{indent}}\n"
            else
              body = emit_indented_block(node.body, needs_return: true)
              "#{function_qualifier}#{type_name(node.return_type || :float)} #{name}(#{params}) {\n#{body}#{indent}}\n"
            end
          end

          def emit_result_struct(func_name, types)
            fields = types.each_with_index.map { |type, index| "#{type_name(type)} v#{index};" }.join(" ")
            "typedef struct { #{fields} } #{func_name}_result;\n"
          end

          def current_return_struct_name
            @return_struct_name_stack.last || "result"
          end

          def emit_array_literal(node, for_static_init: false)
            elements = node.elements.map { |elem| emit_for_static_init(elem, for_static_init) }.join(", ")
            "{#{elements}}"
          end

          def emit_for_static_init(node, for_static_init)
            return emit(node) unless for_static_init

            case node
            when IR::FuncCall
              if %i[vec2 vec3 vec4].include?(node.name)
                args = node.args.map { |arg| emit_for_static_init(arg, true) }.join(", ")
                "{#{args}}"
              else
                emit(node)
              end
            when IR::ArrayLiteral
              emit_array_literal(node, for_static_init: true)
            else
              emit(node)
            end
          end

          def emit_global_decl(node)
            prefix = ""
            prefix += "static " if node.is_static
            prefix += "const " if node.is_const

            if node.initializer.is_a?(IR::ArrayLiteral)
              elem_type = type_name(node.element_type || :float)
              size = node.array_size || node.initializer.elements.length
              elements = emit_array_literal(node.initializer, for_static_init: true)
              "#{prefix}#{elem_type} #{node.name}[#{size}] = #{elements}"
            else
              value = node.is_static ? emit_for_static_init(node.initializer, true) : emit(node.initializer)
              "#{prefix}#{type_name(node.type || :float)} #{node.name} = #{value}"
            end
          end

          def emit_multiple_assignment(node)
            value_code = emit(node.value)

            if node.value.is_a?(IR::FuncCall)
              emit_multi_return_assignment(node, value_code)
            elsif node.value.is_a?(IR::ArrayLiteral)
              emit_literal_assignment(node)
            else
              emit_indexed_assignment(node, value_code)
            end
          end

          private

          def emit_multi_return_assignment(node, value_code)
            func_name = node.value.name
            temporary = next_temporary_name("result")
            lines = [emit_temporary_declaration("#{func_name}_result", temporary, value_code)]
            node.targets.each_with_index do |target, index|
              lines << "#{emit_multiple_assignment_target(target, node.declarations[index])} = #{temporary}.v#{index}"
            end
            lines.join(";\n#{indent}")
          end

          def emit_indexed_assignment(node, value_code)
            node.targets.each_with_index.map do |target, index|
              "#{emit_multiple_assignment_target(target, node.declarations[index])} = #{value_code}[#{index}]"
            end.join(";\n#{indent}")
          end

          def emit_literal_assignment(node)
            temporaries = node.value.elements.map do |element|
              name = next_temporary_name("value")
              [name, emit_temporary_declaration(type_name(element.type || :float), name, emit(element))]
            end
            lines = temporaries.map(&:last)
            node.targets.each_with_index do |target, index|
              lines << "#{emit_multiple_assignment_target(target, node.declarations[index])} = #{temporaries[index].first}"
            end
            lines.join(";\n#{indent}")
          end

          def emit_multiple_assignment_target(target, declaration)
            declaration ? "#{type_name(target.type || :float)} #{target.name}" : target.name.to_s
          end

          def emit_temporary_declaration(type, name, value)
            "#{type} #{name} = #{value}"
          end
        end
      end
    end
  end
end
