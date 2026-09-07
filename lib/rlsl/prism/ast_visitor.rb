# frozen_string_literal: true

require "prism"
require "set"

require_relative "node_traversal"
require_relative "errors"
require_relative "parameter_list"
require_relative "ast_visitor/visitor_registry"
require_relative "ast_visitor/scope_context"
require_relative "ast_visitor/expression_visiting"
require_relative "ast_visitor/control_flow_visiting"
require_relative "ast_visitor/definition_visiting"

module RLSL
  module Prism
    class ASTVisitor
      MAX_AST_DEPTH = 512
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
        @source_name = context[:source_name] || "(shader source)"
        @line_offset = context[:line_offset].to_i
        params = context[:params] || []
        @scope_context = ScopeContext.new(params: params)
        positional_types = params.each_with_index.to_h do |name, index|
          [name.to_sym, %i[vec2 vec2 uniforms][index]]
        end
        @parameter_types = { frag_coord: :vec2, resolution: :vec2, u: :uniforms }.merge(positional_types)
        @parameter_bindings = { frag_coord: :frag_coord, resolution: :resolution, u: :u }
        @implicit_loop_index = 0
        params.each_with_index do |name, index|
          @parameter_bindings[name.to_sym] = %i[frag_coord resolution u][index]
        end
      end

      def parse(source)
        result = ::Prism.parse(source)

        unless result.success?
          errors = result.errors.map(&:message).join(", ")
          raise RLSL::ParseError, "Parse error: #{errors}"
        end

        program = result.value
        if NodeTraversal.depth_exceeds?(program, MAX_AST_DEPTH)
          raise UnsupportedSyntaxError, "Shader syntax nesting exceeds #{MAX_AST_DEPTH} nodes"
        end

        visit(program)
      end

      def visit(node)
        return nil if node.nil?

        method_name = NODE_VISITORS[node.class]
        result = if method_name
                   send(method_name, node)
                 else
                   raise UnsupportedSyntaxError, "Unsupported Prism node: #{node.class}" unless transparent_node?(node)

                   visit_default(node)
                 end
        attach_source_location(result, node.location)
      rescue RLSL::Error => error
        error.with_source_location(source_location(node.location))
        raise
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
        @parameter_types[name.to_sym]
      end

      def emitted_parameter_name(name)
        @parameter_bindings[name.to_sym] || name.to_sym
      end

      def extract_required_params(node)
        ParameterList.required_names(node).map(&:to_sym)
      end

      def extract_block_params(node)
        return [] unless node&.parameters

        extract_required_params(node.parameters.parameters)
      end

      def parameter_reference?(name)
        @scope_context.parameter?(name)
      end

      def fragment_parameter_reference?(name)
        @scope_context.root_parameter?(name)
      end

      def known_variable?(name)
        @scope_context.known_variable?(name)
      end

      def declare_variable(name)
        @scope_context.declare(name)
      end

      def next_implicit_loop_variable
        name = :"_rlsl_i#{@implicit_loop_index}"
        @implicit_loop_index += 1
        name
      end

      def attach_source_location(result, prism_location)
        return result unless result.is_a?(IR::Node)

        result.location ||= source_location(prism_location)
        result
      end

      def source_location(prism_location)
        RLSL::SourceLocation.new(
          source_name: @source_name,
          line: @line_offset + prism_location.start_line,
          column: prism_location.start_column + 1
        )
      end
    end
  end
end
