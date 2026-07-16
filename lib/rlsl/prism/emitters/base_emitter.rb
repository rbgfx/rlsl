# frozen_string_literal: true

require_relative "base_emitter/control_flow_emission"
require_relative "base_emitter/expression_emission"
require_relative "base_emitter/definition_emission"
require_relative "base_emitter/statement_emission"

module RLSL
  module Prism
    module Emitters
      class BaseEmitter
        include ControlFlowEmission
        include ExpressionEmission
        include DefinitionEmission
        include StatementEmission

        PRECEDENCE = {
          "||" => 1,
          "&&" => 2,
          "==" => 3, "!=" => 3,
          "<" => 4, ">" => 4, "<=" => 4, ">=" => 4,
          "+" => 5, "-" => 5,
          "*" => 6, "/" => 6, "%" => 6
        }.freeze

        MULTILINE_NODES = [
          IR::IfStatement,
          IR::ForLoop,
          IR::WhileLoop,
          IR::FunctionDefinition
        ].freeze

        {
          block: :emit_block,
          var_decl: :emit_var_decl,
          var_ref: :emit_var_ref,
          literal: :emit_literal,
          bool_literal: :emit_bool_literal,
          binary_op: :emit_binary_op,
          unary_op: :emit_unary_op,
          func_call: :emit_func_call,
          field_access: :emit_field_access,
          swizzle: :emit_swizzle,
          if_statement: :emit_if_statement,
          ternary: :emit_ternary,
          return: :emit_return,
          assignment: :emit_assignment,
          for_loop: :emit_for_loop,
          while_loop: :emit_while_loop,
          break: :emit_break,
          constant: :emit_constant,
          parenthesized: :emit_parenthesized,
          function_definition: :emit_function_definition,
          array_literal: :emit_array_literal,
          array_index: :emit_array_index,
          global_decl: :emit_global_decl,
          multiple_assignment: :emit_multiple_assignment
        }.each do |visit_name, emitter_name|
          define_method(:"visit_#{visit_name}") do |node|
            send(emitter_name, node)
          end
        end

        attr_reader :indent_level

        def initialize
          @indent_level = 0
          @return_context_stack = [false]
          @return_struct_name_stack = []
        end

        def emit(node, needs_return: false)
          with_return_context(needs_return) do
            return node.accept(self) if node.respond_to?(:accept)

            raise "Unknown IR node: #{node.class}"
          end
        end

        protected

        def type_name(type)
          type.to_s
        end

        def format_number(value, type: nil)
          return value.to_i.to_s if type == :int || value.is_a?(Integer)

          if value.is_a?(Float)
            formatted = value.to_s
            formatted += ".0" unless formatted.include?(".")
            formatted
          else
            value.to_s
          end
        end

        def indent
          "  " * @indent_level
        end

        def emit_with_precedence(node, parent_op, side: :left)
          code = emit(node)
          return code unless node.is_a?(IR::BinaryOp)

          node_prec = PRECEDENCE[node.operator] || 10
          parent_prec = PRECEDENCE[parent_op] || 10
          needs_parentheses = node_prec < parent_prec || (side == :right && node_prec == parent_prec)
          needs_parentheses ? "(#{code})" : code
        end

        def function_name(name)
          name.to_s
        end

        def function_qualifier
          "static inline "
        end

        def with_return_struct_name(name)
          @return_struct_name_stack << name
          yield
        ensure
          @return_struct_name_stack.pop
        end

        def with_return_context(enabled)
          @return_context_stack << enabled
          yield
        ensure
          @return_context_stack.pop
        end

        def return_context?
          @return_context_stack.last
        end
      end
    end
  end
end
