# frozen_string_literal: true

module RLSL
  module Prism
    class ASTVisitor
      module ControlFlowVisiting
        private

        def visit_block(node)
          visit_with_scoped_vars(node.body, params: extract_block_params(node))
        end

        def visit_lambda(node)
          visit_block(node)
        end

        def visit_if(node)
          condition = visit(node.predicate)
          then_branch = visit_with_scoped_vars(node.statements)
          else_branch = node.subsequent ? visit_with_scoped_vars(node.subsequent) : nil

          IR::IfStatement.new(condition, then_branch, else_branch)
        end

        def visit_else(node)
          visit(node.statements)
        end

        def visit_elsif(node)
          visit_if(node)
        end

        def visit_if_node(node)
          visit_if(node)
        end

        def visit_unless(node)
          condition = IR::UnaryOp.new("!", visit(node.predicate))
          then_branch = visit_with_scoped_vars(node.statements)
          else_branch = node.else_clause ? visit_with_scoped_vars(node.else_clause) : nil

          IR::IfStatement.new(condition, then_branch, else_branch)
        end

        def visit_return(node)
          expr = node.arguments ? normalize_expression(visit(node.arguments.arguments.first)) : nil
          IR::Return.new(expr)
        end

        def visit_range(node)
          [visit(node.left), visit(node.right)]
        end

        def visit_for(node)
          range = visit(node.collection)
          body = visit(node.statements)
          IR::ForLoop.new(node.index.name.to_sym, range[0], range[1], body)
        end

        def visit_call_with_block(node)
          return visit_call(node) unless times_loop?(node)

          count = visit(node.receiver)
          block = visit(node.block)
          var_name = extract_block_params(node.block).first || :i
          IR::ForLoop.new(var_name, IR::Literal.new(0, :int), count, block)
        end

        def visit_while(node)
          IR::WhileLoop.new(visit(node.predicate), visit(node.statements))
        end

        def visit_break(_node)
          IR::Break.new
        end

        def times_loop?(node)
          node.name.to_s == "times" && node.receiver
        end
      end
    end
  end
end
