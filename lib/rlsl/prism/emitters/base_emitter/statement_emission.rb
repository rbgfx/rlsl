# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class BaseEmitter
        module StatementEmission
          def emit_block(node, needs_return = nil)
            statements = node.statements
            return "" if statements.empty?

            emit_statements(statements, returning: needs_return.nil? ? return_context? : needs_return)
          end

          def emit_statements(statements, returning:)
            return statements.map { |statement| emit_statement(statement) }.join unless returning

            leading = statements[0...-1].map { |statement| emit_statement(statement) }.join
            leading + emit_terminal_statement(statements.last)
          end

          def emit_statement(node, needs_return: false)
            return emit_terminal_statement(node) if needs_return

            "#{indent}#{emit(node)}#{statement_terminator(node)}"
          end

          def emit_terminal_statement(node)
            return emit(node, needs_return: true) if node.is_a?(IR::IfStatement)
            return emit_statement(node) if terminal_passthrough_node?(node)
            return emit_tuple_return(node) if node.is_a?(IR::ArrayLiteral)

            "#{indent}return #{emit(node)};\n"
          end

          def emit_with_return(node)
            emit_terminal_statement(node)
          end

          def emit_branch(node, needs_return:)
            with_indent do
              if node.is_a?(IR::Block)
                emit(node, needs_return: needs_return)
              else
                emit_statement(node, needs_return: needs_return)
              end
            end
          end

          def emit_indented_block(node, needs_return: false)
            with_indent do
              if node.is_a?(IR::Block)
                emit(node, needs_return: needs_return)
              else
                emit_statement(node, needs_return: needs_return)
              end
            end
          end

          private

          def statement_terminator(node)
            multiline_node?(node) ? "\n" : ";\n"
          end

          def multiline_node?(node)
            MULTILINE_NODES.any? { |klass| node.is_a?(klass) }
          end

          def terminal_passthrough_node?(node)
            [
              IR::Return,
              IR::VarDecl,
              IR::Assignment,
              IR::ForLoop,
              IR::WhileLoop,
              IR::FunctionDefinition,
              IR::GlobalDecl,
              IR::MultipleAssignment
            ].any? { |klass| node.is_a?(klass) }
          end

          def with_indent
            @indent_level += 1
            yield
          ensure
            @indent_level -= 1
          end
        end
      end
    end
  end
end
