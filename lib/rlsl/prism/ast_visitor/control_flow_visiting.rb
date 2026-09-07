# frozen_string_literal: true

module RLSL
  module Prism
    class ASTVisitor
      module ControlFlowVisiting
        VISITORS = {}.tap do |visitors|
          visitors[::Prism::BlockNode] = :visit_block if defined?(::Prism::BlockNode)
          visitors[::Prism::LambdaNode] = :visit_lambda if defined?(::Prism::LambdaNode)
          visitors[::Prism::IfNode] = :visit_if if defined?(::Prism::IfNode)
          visitors[::Prism::ElseNode] = :visit_else if defined?(::Prism::ElseNode)
          visitors[::Prism::UnlessNode] = :visit_unless if defined?(::Prism::UnlessNode)
          visitors[::Prism::ReturnNode] = :visit_return if defined?(::Prism::ReturnNode)
          visitors[::Prism::RangeNode] = :visit_range if defined?(::Prism::RangeNode)
          visitors[::Prism::ForNode] = :visit_for if defined?(::Prism::ForNode)
          visitors[::Prism::WhileNode] = :visit_while if defined?(::Prism::WhileNode)
          visitors[::Prism::BreakNode] = :visit_break if defined?(::Prism::BreakNode)
        end.freeze

        private

        def visit_block(node)
          visit_with_scoped_vars(node.body, params: extract_block_params(node))
        end

        def visit_lambda(node)
          visit_block(node)
        end

        def visit_if(node)
          condition = visit(node.predicate)
          hoisted_variables = hoist_branch_variables(node)
          then_branch = visit_with_scoped_vars(node.statements)
          else_branch = node.subsequent ? visit_with_scoped_vars(node.subsequent) : nil

          IR::IfStatement.new(condition, then_branch, else_branch, hoisted_variables: hoisted_variables)
        end

        def visit_else(node)
          visit(node.statements)
        end

        def visit_unless(node)
          condition = IR::UnaryOp.new("!", visit(node.predicate))
          hoisted_variables = hoist_branch_variables(node)
          then_branch = visit_with_scoped_vars(node.statements)
          else_branch = node.else_clause ? visit_with_scoped_vars(node.else_clause) : nil

          IR::IfStatement.new(condition, then_branch, else_branch, hoisted_variables: hoisted_variables)
        end

        def visit_return(node)
          arguments = node.arguments&.arguments || []
          if arguments.length > 1
            raise UnsupportedSyntaxError, "Returning multiple values requires an explicitly declared tuple helper"
          end

          expr = arguments.empty? ? nil : normalize_expression(visit(arguments.first))
          IR::Return.new(expr)
        end

        def visit_range(node)
          [visit(node.left), visit(node.right), node.exclude_end?]
        end

        def visit_for(node)
          range = visit(node.collection)
          variable = node.index.name.to_sym
          body = visit_with_scoped_vars(node.statements, params: [variable]) || IR::Block.new
          IR::ForLoop.new(variable, range[0], range[1], body, exclude_end: range[2])
        end

        def visit_call_with_block(node)
          unless times_loop?(node)
            raise UnsupportedSyntaxError, "Blocks are only supported for Integer#times loops"
          end

          count = visit(node.receiver)
          block_params = extract_block_params(node.block)
          var_name = block_params.first || next_implicit_loop_variable
          block = visit_with_scoped_vars(node.block.body, params: [var_name]) || IR::Block.new
          IR::ForLoop.new(var_name, IR::Literal.new(0, :int), count, block)
        end

        def visit_while(node)
          IR::WhileLoop.new(visit(node.predicate), visit(node.statements) || IR::Block.new)
        end

        def visit_break(_node)
          IR::Break.new
        end

        def times_loop?(node)
          node.name.to_s == "times" && node.receiver
        end

        def hoist_branch_variables(node)
          then_names = definitely_assigned_names(node.statements)
          else_node = node.respond_to?(:subsequent) ? node.subsequent : node.else_clause
          else_names = definitely_assigned_names(else_node)

          (then_names & else_names).each_with_object({}) do |name, variables|
            next if known_variable?(name)

            declare_variable(name)
            variables[name] = nil
          end
        end

        def definitely_assigned_names(node)
          return Set.new unless node

          case node
          when ::Prism::StatementsNode
            node.body.each_with_object(Set.new) do |statement, names|
              names.merge(definitely_assigned_names(statement))
            end
          when ::Prism::LocalVariableWriteNode, ::Prism::LocalVariableOperatorWriteNode
            Set[node.name.to_sym]
          when ::Prism::MultiWriteNode
            Set.new(node.lefts.map { |target| target.name.to_sym })
          when ::Prism::IfNode
            definitely_assigned_names(node.statements) & definitely_assigned_names(node.subsequent)
          when ::Prism::UnlessNode
            definitely_assigned_names(node.statements) & definitely_assigned_names(node.else_clause)
          when ::Prism::ElseNode
            definitely_assigned_names(node.statements)
          else
            Set.new
          end
        end
      end
    end
  end
end
