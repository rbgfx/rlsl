# frozen_string_literal: true

require "prism"
require "set"

require_relative "ast_visitor/scope_context"
require_relative "ast_visitor/expression_visiting"
require_relative "ast_visitor/control_flow_visiting"
require_relative "ast_visitor/definition_visiting"

module RLSL
  module Prism
    class ASTVisitor
      BINARY_OPERATORS = %w[+ - * / % == != < > <= >= && ||].freeze
      UNARY_OPERATORS = %w[- !].freeze

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

        method_name = "visit_#{node_type(node)}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          visit_default(node)
        end
      end

      private

      def node_type(node)
        node.class.name.split("::").last
          .gsub(/Node$/, "")
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
      end

      def visit_default(node)
        children = []
        node.child_nodes.compact.each do |child|
          result = visit(child)
          children << result if result
        end
        children.length == 1 ? children.first : children
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
