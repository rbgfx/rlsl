# frozen_string_literal: true

module RLSL
  module Prism
    class ASTVisitor
      module ExpressionVisiting
        VISITORS = {}.tap do |visitors|
          visitors[::Prism::IntegerNode] = :visit_integer if defined?(::Prism::IntegerNode)
          visitors[::Prism::FloatNode] = :visit_float if defined?(::Prism::FloatNode)
          visitors[::Prism::RationalNode] = :visit_rational if defined?(::Prism::RationalNode)
          visitors[::Prism::TrueNode] = :visit_true if defined?(::Prism::TrueNode)
          visitors[::Prism::FalseNode] = :visit_false if defined?(::Prism::FalseNode)
          visitors[::Prism::ParenthesesNode] = :visit_parentheses if defined?(::Prism::ParenthesesNode)
          visitors[::Prism::CallNode] = :visit_call if defined?(::Prism::CallNode)
          visitors[::Prism::AndNode] = :visit_and if defined?(::Prism::AndNode)
          visitors[::Prism::OrNode] = :visit_or if defined?(::Prism::OrNode)
          visitors[::Prism::NotNode] = :visit_not if defined?(::Prism::NotNode)
          visitors[::Prism::ArrayNode] = :visit_array if defined?(::Prism::ArrayNode)
          visitors[::Prism::ConstantReadNode] = :visit_constant_read if defined?(::Prism::ConstantReadNode)
          visitors[::Prism::ConstantPathNode] = :visit_constant_path if defined?(::Prism::ConstantPathNode)
          visitors[::Prism::GlobalVariableReadNode] = :visit_global_variable_read if defined?(::Prism::GlobalVariableReadNode)
        end.freeze

        private

        def visit_integer(node)
          IR::Literal.new(node.value, :int)
        end

        def visit_float(node)
          IR::Literal.new(node.value, :float)
        end

        def visit_rational(node)
          IR::Literal.new(node.value.to_f, :float)
        end

        def visit_true(_node)
          IR::BoolLiteral.new(true)
        end

        def visit_false(_node)
          IR::BoolLiteral.new(false)
        end

        def visit_parentheses(node)
          inner = normalize_expression(visit(node.body))
          inner = inner.statements.first if single_statement_block?(inner)
          IR::Parenthesized.new(inner)
        end

        def visit_call(node)
          return visit_call_with_block(node) if node.block

          visit_plain_call(node)
        end

        def visit_plain_call(node)
          method_name = node.name.to_s
          receiver = normalize_expression(visit(node.receiver)) if node.receiver
          args = node.arguments&.arguments&.map { |arg| normalize_expression(visit(arg)) } || []

          if parameter_reference_call?(method_name, receiver, args)
            return IR::VarRef.new(emitted_parameter_name(method_name), infer_param_type(method_name))
          end
          return visit_receiver_call(method_name, receiver) if receiver_without_arguments?(node, receiver, args)
          return IR::BinaryOp.new(method_name, receiver, args.first) if binary_operator_call?(method_name, receiver, args)
          return IR::UnaryOp.new("-", receiver) if method_name == "-@" && receiver
          return IR::UnaryOp.new("!", args.first) if method_name == "!" && args.length == 1
          return IR::ArrayIndex.new(receiver, args.first) if method_name == "[]" && receiver && args.length == 1

          IR::FuncCall.new(method_name.to_sym, args, receiver)
        end

        def visit_and(node)
          left = normalize_expression(visit(node.left))
          right = normalize_expression(visit(node.right))
          IR::BinaryOp.new("&&", left, right, :bool)
        end

        def visit_or(node)
          left = normalize_expression(visit(node.left))
          right = normalize_expression(visit(node.right))
          IR::BinaryOp.new("||", left, right, :bool)
        end

        def visit_not(node)
          operand = normalize_expression(visit(node.expression))
          IR::UnaryOp.new("!", operand, :bool)
        end

        def visit_array(node)
          elements = node.elements.map { |elem| normalize_expression(visit(elem)) }
          IR::ArrayLiteral.new(elements)
        end

        def visit_index(node)
          array = normalize_expression(visit(node.receiver))
          index = normalize_expression(visit(node.arguments.arguments.first))
          IR::ArrayIndex.new(array, index)
        end

        def visit_constant_read(node)
          name = node.name.to_s
          return IR::Constant.new(name.to_sym, :float) if %w[PI TAU].include?(name)

          IR::VarRef.new(name.to_sym)
        end

        def visit_constant_path(node)
          path_parts = []
          current = node
          while current.is_a?(::Prism::ConstantPathNode)
            path_parts.unshift(current.name.to_s)
            current = current.parent
          end
          path_parts.unshift(current.name.to_s) if current.respond_to?(:name)

          IR::VarRef.new(path_parts.join("_").to_sym)
        end

        def visit_global_variable_read(node)
          IR::VarRef.new(node.name.to_s.sub(/^\$/, "").to_sym)
        end

        def normalize_expression(node)
          return node unless node.is_a?(IR::IfStatement)

          then_expr = extract_if_branch_expr(node.then_branch)
          else_expr = extract_if_branch_expr(node.else_branch)
          raise "Unsupported if-expression: branches must be single expressions" unless then_expr && else_expr

          IR::Ternary.new(node.condition, then_expr, else_expr)
        end

        def extract_if_branch_expr(branch)
          return nil unless branch
          return branch unless branch.is_a?(IR::Block)
          return nil if branch.statements.empty? || branch.statements.length != 1

          branch.statements.first
        end

        def single_statement_block?(node)
          node.is_a?(IR::Block) && node.statements.length == 1
        end

        def parameter_reference_call?(method_name, receiver, args)
          !receiver && args.empty? &&
            (parameter_reference?(method_name.to_sym) || infer_param_type(method_name.to_sym))
        end

        def receiver_without_arguments?(node, receiver, args)
          receiver && args.empty? && !node.arguments
        end

        def visit_receiver_call(method_name, receiver)
          return receiver if method_name == "freeze"
          return IR::FieldAccess.new(receiver, method_name, :float) if Builtins.single_component_field?(method_name)
          return IR::Swizzle.new(receiver, method_name, Builtins.swizzle_type(method_name)) if Builtins.swizzle?(method_name)

          IR::FieldAccess.new(receiver, method_name)
        end

        def binary_operator_call?(method_name, receiver, args)
          BINARY_OPERATORS.include?(method_name) && receiver && args.length == 1
        end
      end
    end
  end
end
