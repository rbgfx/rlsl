# frozen_string_literal: true

module RLSL
  module Prism
    module IR
      module Traversal
        module_function

        def each(node, &block)
          return enum_for(:each, node) unless block_given?
          return if node.nil?

          stack = [node]
          until stack.empty?
            current = stack.pop
            yield current
            stack.concat(child_nodes(current).reverse)
          end
        end

        def child_nodes(node)
          case node
          when Block
            node.statements
          when VarDecl
            [node.initializer]
          when BinaryOp
            [node.left, node.right]
          when UnaryOp
            [node.operand]
          when FuncCall
            [node.receiver, *node.args]
          when FieldAccess, Swizzle
            [node.receiver]
          when IfStatement
            [node.condition, node.then_branch, node.else_branch]
          when Ternary
            [node.condition, node.then_expr, node.else_expr]
          when Return
            [node.expression]
          when Assignment
            [node.target, node.value]
          when ForLoop
            [node.range_start, node.range_end, node.body]
          when WhileLoop
            [node.condition, node.body]
          when Parenthesized
            [node.expression]
          when ArrayLiteral
            node.elements
          when ArrayIndex
            [node.array, node.index]
          when GlobalDecl
            [node.initializer]
          when FunctionDefinition
            [node.body]
          when MultipleAssignment
            [*node.targets, node.value]
          else
            []
          end.compact
        end
      end
    end
  end
end
