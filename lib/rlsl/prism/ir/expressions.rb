# frozen_string_literal: true

module RLSL
  module Prism
    module IR
      class Block < Node
        attr_reader :statements

        visits :visit_block

        def initialize(statements = [])
          super()
          @statements = statements
        end
      end

      class VarDecl < Node
        attr_reader :name, :initializer
        attr_accessor :mutable

        visits :visit_var_decl

        def initialize(name, initializer, type = nil, mutable: false)
          super()
          @name = name
          @initializer = initializer
          @type = type
          @mutable = mutable
        end
      end

      class VarRef < Node
        attr_reader :name

        visits :visit_var_ref

        def initialize(name, type = nil)
          super()
          @name = name
          @type = type
        end
      end

      class Literal < Node
        attr_reader :value

        visits :visit_literal

        def initialize(value, type = nil)
          super()
          @value = value
          @type = type || (value.is_a?(Float) ? :float : :int)
        end
      end

      class BoolLiteral < Node
        attr_reader :value

        visits :visit_bool_literal

        def initialize(value)
          super()
          @value = value
          @type = :bool
        end
      end

      class BinaryOp < Node
        attr_reader :operator, :left, :right

        visits :visit_binary_op

        def initialize(operator, left, right, type = nil)
          super()
          @operator = operator
          @left = left
          @right = right
          @type = type
        end
      end

      class UnaryOp < Node
        attr_reader :operator, :operand

        visits :visit_unary_op

        def initialize(operator, operand, type = nil)
          super()
          @operator = operator
          @operand = operand
          @type = type
        end
      end

      class FuncCall < Node
        attr_reader :name, :args, :receiver

        visits :visit_func_call

        def initialize(name, args = [], receiver = nil, type = nil)
          super()
          @name = name
          @args = args
          @receiver = receiver
          @type = type
        end
      end

      class FieldAccess < Node
        attr_reader :receiver, :field

        visits :visit_field_access

        def initialize(receiver, field, type = nil)
          super()
          @receiver = receiver
          @field = field
          @type = type
        end
      end

      class Swizzle < Node
        attr_reader :receiver, :components

        visits :visit_swizzle

        def initialize(receiver, components, type = nil)
          super()
          @receiver = receiver
          @components = components
          @type = type
        end
      end

      class Ternary < Node
        attr_reader :condition, :then_expr, :else_expr

        visits :visit_ternary

        def initialize(condition, then_expr, else_expr, type = nil)
          super()
          @condition = condition
          @then_expr = then_expr
          @else_expr = else_expr
          @type = type
        end
      end

      class Constant < Node
        attr_reader :name

        visits :visit_constant

        def initialize(name, type = :float)
          super()
          @name = name
          @type = type
        end
      end

      class Parenthesized < Node
        attr_reader :expression

        visits :visit_parenthesized

        def initialize(expression)
          super()
          @expression = expression
          @type = expression&.type
        end
      end

      class ArrayLiteral < Node
        attr_reader :elements

        visits :visit_array_literal

        def initialize(elements, type = nil)
          super()
          @elements = elements
          @type = type
        end
      end

      class ArrayIndex < Node
        attr_reader :array, :index

        visits :visit_array_index

        def initialize(array, index, type = nil)
          super()
          @array = array
          @index = index
          @type = type
        end
      end
    end
  end
end
