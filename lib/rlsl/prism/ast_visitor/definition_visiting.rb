# frozen_string_literal: true

module RLSL
  module Prism
    class ASTVisitor
      module DefinitionVisiting
        VISITORS = {}.tap do |visitors|
          visitors[::Prism::LocalVariableWriteNode] = :visit_local_variable_write if defined?(::Prism::LocalVariableWriteNode)
          visitors[::Prism::LocalVariableOperatorWriteNode] = :visit_local_variable_operator_write if defined?(::Prism::LocalVariableOperatorWriteNode)
          visitors[::Prism::LocalVariableReadNode] = :visit_local_variable_read if defined?(::Prism::LocalVariableReadNode)
          visitors[::Prism::DefNode] = :visit_def if defined?(::Prism::DefNode)
          visitors[::Prism::GlobalVariableWriteNode] = :visit_global_variable_write if defined?(::Prism::GlobalVariableWriteNode)
          visitors[::Prism::ConstantWriteNode] = :visit_constant_write if defined?(::Prism::ConstantWriteNode)
          visitors[::Prism::MultiWriteNode] = :visit_multi_write if defined?(::Prism::MultiWriteNode)
          visitors[::Prism::LocalVariableTargetNode] = :visit_local_variable_target if defined?(::Prism::LocalVariableTargetNode)
        end.freeze

        private

        def visit_local_variable_write(node)
          name = node.name.to_sym
          value = normalize_expression(visit(node.value))
          emitted_name = fragment_parameter_reference?(name) ? emitted_parameter_name(name) : name

          if known_variable?(name)
            IR::Assignment.new(IR::VarRef.new(emitted_name), value)
          else
            declare_variable(name)
            IR::VarDecl.new(name, value)
          end
        end

        def visit_local_variable_operator_write(node)
          name = node.name.to_sym
          operator = node.binary_operator.to_s
          value = normalize_expression(visit(node.value))

          unless known_variable?(name)
            raise UnsupportedSyntaxError, "Operator assignment requires an initialized variable: #{name}"
          end
          emitted_name = fragment_parameter_reference?(name) ? emitted_parameter_name(name) : name
          target = IR::VarRef.new(emitted_name)
          expr = IR::BinaryOp.new(operator, IR::VarRef.new(emitted_name), IR::Parenthesized.new(value))
          IR::Assignment.new(target, expr)
        end

        def visit_local_variable_read(node)
          name = node.name.to_sym
          emitted_name = fragment_parameter_reference?(name) ? emitted_parameter_name(name) : name
          type = infer_param_type(name) if fragment_parameter_reference?(name)
          IR::VarRef.new(emitted_name, type)
        end

        def visit_def(node)
          params = extract_required_params(node.parameters)
          body = visit_with_scoped_vars(node.body, params: params)
          IR::FunctionDefinition.new(node.name.to_sym, params, body)
        end

        def visit_global_variable_write(node)
          IR::GlobalDecl.new(node.name.to_s.sub(/^\$/, "").to_sym, visit(node.value), is_static: true)
        end

        def visit_constant_write(node)
          IR::GlobalDecl.new(node.name.to_sym, visit(node.value), is_const: true, is_static: true)
        end

        def visit_multi_write(node)
          if node.rest || !node.rights.empty?
            raise UnsupportedSyntaxError, "Splat multiple assignment is not supported"
          end

          declarations = []
          targets = node.lefts.map do |target|
            name = target.name.to_sym
            declarations << !known_variable?(name)
            declare_variable(name) if declarations.last
            emitted_name = fragment_parameter_reference?(name) ? emitted_parameter_name(name) : name
            IR::VarRef.new(emitted_name)
          end

          IR::MultipleAssignment.new(targets, visit(node.value), declarations: declarations)
        end

        def visit_local_variable_target(node)
          name = node.name.to_sym
          declare_variable(name)
          IR::VarRef.new(name)
        end
      end
    end
  end
end
