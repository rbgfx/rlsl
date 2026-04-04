# frozen_string_literal: true

require "prism"
require "set"

require_relative "ast_visitor/scope_context"
require_relative "ast_visitor/expression_visiting"
require_relative "ast_visitor/control_flow_visiting"
require_relative "ast_visitor/definition_visiting"

module RLSL
  module Prism
    class UnsupportedSyntaxError < StandardError; end

    class ASTVisitor
      BINARY_OPERATORS = %w[+ - * / % == != < > <= >= && ||].freeze
      UNARY_OPERATORS = %w[- !].freeze
      TRANSPARENT_NODES = [
        (::Prism::ArgumentsNode if defined?(::Prism::ArgumentsNode)),
        (::Prism::BlockParametersNode if defined?(::Prism::BlockParametersNode)),
        (::Prism::ParametersNode if defined?(::Prism::ParametersNode))
      ].compact.freeze
      NODE_VISITORS = {}.tap do |visitors|
        visitors[::Prism::ProgramNode] = :visit_program if defined?(::Prism::ProgramNode)
        visitors[::Prism::StatementsNode] = :visit_statements if defined?(::Prism::StatementsNode)
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
        visitors[::Prism::LocalVariableWriteNode] = :visit_local_variable_write if defined?(::Prism::LocalVariableWriteNode)
        visitors[::Prism::LocalVariableOperatorWriteNode] = :visit_local_variable_operator_write if defined?(::Prism::LocalVariableOperatorWriteNode)
        visitors[::Prism::LocalVariableReadNode] = :visit_local_variable_read if defined?(::Prism::LocalVariableReadNode)
        visitors[::Prism::DefNode] = :visit_def if defined?(::Prism::DefNode)
        visitors[::Prism::GlobalVariableWriteNode] = :visit_global_variable_write if defined?(::Prism::GlobalVariableWriteNode)
        visitors[::Prism::ConstantWriteNode] = :visit_constant_write if defined?(::Prism::ConstantWriteNode)
        visitors[::Prism::MultiWriteNode] = :visit_multi_write if defined?(::Prism::MultiWriteNode)
        visitors[::Prism::LocalVariableTargetNode] = :visit_local_variable_target if defined?(::Prism::LocalVariableTargetNode)
      end.freeze

      include ExpressionVisiting
      include ControlFlowVisiting
      include DefinitionVisiting

      def initialize(context = {})
        @context = context
        @uniforms = context[:uniforms] || {}
        @scope_context = ScopeContext.new(params: context[:params] || [])
      end

      def parse(source)
        result = ::Prism.parse(source)

        unless result.success?
          errors = result.errors.map(&:message).join(", ")
          raise "Parse error: #{errors}"
        end

        program = result.value
        visit(program)
      end

      def visit(node)
        return nil if node.nil?

        method_name = NODE_VISITORS[node.class]
        return send(method_name, node) if method_name

        raise UnsupportedSyntaxError, "Unsupported Prism node: #{node.class}" unless transparent_node?(node)

        visit_default(node)
      end

      private

      def visit_default(node)
        children = []
        node.child_nodes.compact.each do |child|
          result = visit(child)
          children << result if result
        end
        children.length == 1 ? children.first : children
      end

      def transparent_node?(node)
        TRANSPARENT_NODES.include?(node.class)
      end

      def visit_program(node)
        visit(node.statements)
      end

      def visit_statements(node)
        statements = node.body.map { |stmt| visit(stmt) }.compact.flatten
        IR::Block.new(statements)
      end

      def visit_with_scoped_vars(node, params: [])
        @scope_context.with_scope(params: params) { visit(node) }
      end

      def infer_param_type(name)
        case name
        when :frag_coord, :resolution
          :vec2
        when :u
          :uniforms
        else
          nil
        end
      end

      def extract_required_params(node)
        return [] unless node

        node.requireds&.map { |param| param.name.to_sym } || []
      end

      def extract_block_params(node)
        return [] unless node&.parameters

        extract_required_params(node.parameters.parameters)
      end

      def parameter_reference?(name)
        @scope_context.parameter?(name)
      end

      def known_variable?(name)
        @scope_context.known_variable?(name)
      end

      def declare_variable(name)
        @scope_context.declare(name)
      end
    end
  end
end
