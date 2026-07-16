# frozen_string_literal: true

module RLSL
  module Prism
    module IR
      class IfStatement < Node
        attr_reader :condition, :then_branch, :else_branch, :hoisted_variables

        visits :visit_if_statement

        def initialize(condition, then_branch, else_branch = nil, type = nil, hoisted_variables: {})
          super()
          @condition = condition
          @then_branch = then_branch
          @else_branch = else_branch
          @hoisted_variables = hoisted_variables
          @type = type
        end
      end

      class Return < Node
        attr_reader :expression

        visits :visit_return

        def initialize(expression)
          super()
          @expression = expression
          @type = expression&.type
        end
      end

      class Assignment < Node
        attr_reader :target, :value

        visits :visit_assignment

        def initialize(target, value)
          super()
          @target = target
          @value = value
          @type = value&.type
        end
      end

      class ForLoop < Node
        attr_reader :variable, :range_start, :range_end, :body, :exclude_end

        visits :visit_for_loop

        def initialize(variable, range_start, range_end, body, exclude_end: true)
          super()
          @variable = variable
          @range_start = range_start
          @range_end = range_end
          @body = body
          @exclude_end = exclude_end
          @type = nil
        end
      end

      class WhileLoop < Node
        attr_reader :condition, :body

        visits :visit_while_loop

        def initialize(condition, body)
          super()
          @condition = condition
          @body = body
          @type = nil
        end
      end

      class Break < Node
        visits :visit_break

        def initialize
          super()
          @type = nil
        end
      end
    end
  end
end
