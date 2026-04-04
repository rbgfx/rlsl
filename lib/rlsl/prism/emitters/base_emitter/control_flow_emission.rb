# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class BaseEmitter
        module ControlFlowEmission
          def emit_tuple_return(node)
            elements = node.elements.map { |elem| emit(elem) }.join(", ")
            "#{indent}return (#{current_return_struct_name}){#{elements}};\n"
          end

          def emit_if_statement(node)
            emit_conditional(node, needs_return: return_context?)
          end

          def emit_conditional(node, needs_return:)
            condition = emit(node.condition)
            then_code = emit_branch(node.then_branch, needs_return: needs_return)

            return "#{indent}if (#{condition}) {\n#{then_code}#{indent}}#{needs_return ? "\n" : ""}" unless node.else_branch

            if elsif_node?(node.else_branch)
              elsif_code = emit_elsif(node.else_branch, needs_return: needs_return)
              "#{indent}if (#{condition}) {\n#{then_code}#{indent}} #{elsif_code}#{needs_return ? "\n" : ""}"
            else
              else_code = emit_branch(node.else_branch, needs_return: needs_return)
              "#{indent}if (#{condition}) {\n#{then_code}#{indent}} else {\n#{else_code}#{indent}}#{needs_return ? "\n" : ""}"
            end
          end

          def emit_elsif(node, needs_return: false)
            if_node = node.is_a?(IR::Block) ? node.statements.first : node
            condition = emit(if_node.condition)
            then_code = emit_branch(if_node.then_branch, needs_return: needs_return)

            return "else if (#{condition}) {\n#{then_code}#{indent}}" unless if_node.else_branch

            if elsif_node?(if_node.else_branch)
              elsif_code = emit_elsif(if_node.else_branch, needs_return: needs_return)
              "else if (#{condition}) {\n#{then_code}#{indent}} #{elsif_code}"
            else
              else_code = emit_branch(if_node.else_branch, needs_return: needs_return)
              "else if (#{condition}) {\n#{then_code}#{indent}} else {\n#{else_code}#{indent}}"
            end
          end

          def elsif_node?(node)
            return true if node.is_a?(IR::IfStatement)
            return false unless node.is_a?(IR::Block)

            node.statements.length == 1 && node.statements.first.is_a?(IR::IfStatement)
          end

          def emit_return(node)
            node.expression ? "return #{emit(node.expression)}" : "return"
          end

          def emit_for_loop(node)
            var = node.variable
            start_val = emit(node.range_start)
            end_val = emit(node.range_end)
            body = emit_indented_block(node.body)

            "for (int #{var} = #{start_val}; #{var} < #{end_val}; #{var}++) {\n#{body}#{indent}}"
          end

          def emit_while_loop(node)
            condition = emit(node.condition)
            body = emit_indented_block(node.body)

            "while (#{condition}) {\n#{body}#{indent}}"
          end

          def emit_break(_node)
            "break"
          end

        end
      end
    end
  end
end
