# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class BaseEmitter
        module ExpressionEmission
          def emit_var_decl(node)
            type = type_name(node.type || :float)
            value = emit(node.initializer)
            "#{type} #{node.name} = #{value}"
          end

          def emit_var_ref(node)
            node.name.to_s
          end

          def emit_literal(node)
            format_number(node.value)
          end

          def emit_bool_literal(node)
            node.value.to_s
          end

          def emit_binary_op(node)
            left = emit_with_precedence(node.left, node.operator)
            right = emit_with_precedence(node.right, node.operator)
            "#{left} #{node.operator} #{right}"
          end

          def emit_unary_op(node)
            "#{node.operator}#{emit(node.operand)}"
          end

          def emit_func_call(node)
            func_name = function_name(node.name)
            args = node.args.map { |arg| emit(arg) }.join(", ")

            if node.receiver
              receiver = emit(node.receiver)
              "#{func_name}(#{receiver}, #{args})"
            else
              "#{func_name}(#{args})"
            end
          end

          def emit_field_access(node)
            "#{emit(node.receiver)}.#{node.field}"
          end

          def emit_swizzle(node)
            "#{emit(node.receiver)}.#{node.components}"
          end

          def emit_ternary(node)
            "(#{emit(node.condition)} ? #{emit(node.then_expr)} : #{emit(node.else_expr)})"
          end

          def emit_assignment(node)
            "#{emit(node.target)} = #{emit(node.value)}"
          end

          def emit_constant(node)
            case node.name
            when :PI
              "3.14159265358979323846"
            when :TAU
              "6.28318530717958647692"
            else
              node.name.to_s
            end
          end

          def emit_parenthesized(node)
            "(#{emit(node.expression)})"
          end

          def emit_array_index(node)
            array = emit(node.array)
            index = if node.index.is_a?(IR::Literal) && node.index.value.to_i == node.index.value
                      node.index.value.to_i.to_s
                    else
                      emit(node.index)
                    end
            "#{array}[#{index}]"
          end
        end
      end
    end
  end
end
