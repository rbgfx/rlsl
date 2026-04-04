# frozen_string_literal: true

module RLSL
  module Prism
    module Builtins
      module OperatorRules
        BINARY_OPERATORS = {
          "+" => :arithmetic,
          "-" => :arithmetic,
          "*" => :arithmetic,
          "/" => :arithmetic,
          "%" => :arithmetic,

          "==" => :comparison,
          "!=" => :comparison,
          "<" => :comparison,
          ">" => :comparison,
          "<=" => :comparison,
          ">=" => :comparison,

          "&&" => :logical,
          "||" => :logical
        }.freeze

        UNARY_OPERATORS = {
          "-" => :negate,
          "!" => :not
        }.freeze

        module_function

        def binary_operator?(op)
          BINARY_OPERATORS.key?(op.to_s)
        end

        def unary_operator?(op)
          UNARY_OPERATORS.key?(op.to_s)
        end

        def binary_op_result_type(op, left_type, right_type)
          op_kind = BINARY_OPERATORS[op.to_s]

          case op_kind
          when :comparison, :logical
            :bool
          when :arithmetic
            if matrix_type?(left_type) && vector_type?(right_type)
              matrix_vector_result(left_type)
            elsif vector_type?(left_type) && matrix_type?(right_type)
              matrix_vector_result(right_type)
            elsif matrix_type?(left_type) && matrix_type?(right_type)
              left_type
            elsif matrix_type?(left_type) && scalar_type?(right_type)
              left_type
            elsif scalar_type?(left_type) && matrix_type?(right_type)
              right_type
            elsif vector_type?(left_type) && vector_type?(right_type)
              left_type
            elsif vector_type?(left_type) && scalar_type?(right_type)
              left_type
            elsif scalar_type?(left_type) && vector_type?(right_type)
              right_type
            else
              :float
            end
          end
        end

        def vector_type?(type)
          %i[vec2 vec3 vec4].include?(type)
        end

        def matrix_type?(type)
          %i[mat2 mat3 mat4].include?(type)
        end

        def scalar_type?(type)
          %i[float int].include?(type)
        end

        def matrix_vector_result(matrix_type)
          case matrix_type
          when :mat2 then :vec2
          when :mat3 then :vec3
          when :mat4 then :vec4
          end
        end
      end
    end
  end
end
