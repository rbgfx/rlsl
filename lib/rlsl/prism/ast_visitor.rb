# frozen_string_literal: true

require "prism"
require "set"

require_relative "ast_visitor/visitor_registry"
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
      TRANSPARENT_NODES = VisitorRegistry::TRANSPARENT_NODES
      NODE_VISITORS = VisitorRegistry.build(
        {}.tap do |visitors|
          visitors[::Prism::ProgramNode] = :visit_program if defined?(::Prism::ProgramNode)
          visitors[::Prism::StatementsNode] = :visit_statements if defined?(::Prism::StatementsNode)
        end,
        ExpressionVisiting::VISITORS,
        ControlFlowVisiting::VISITORS,
        DefinitionVisiting::VISITORS
      )

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
