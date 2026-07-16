# frozen_string_literal: true

require_relative "type_inference/scope_stack"
require_relative "type_inference/type_shapes"
require_relative "type_inference/inferer_registry"
require_relative "type_inference/call_validator"
require_relative "type_inference/type_environment"
require_relative "type_inference/call_type_resolver"
require_relative "type_inference/field_type_resolver"
require_relative "type_inference/collection_type_resolver"
require_relative "type_inference/expression_inferer"
require_relative "type_inference/definition_inferer"
require_relative "type_inference/control_flow_inferer"

module RLSL
  module Prism
    class SignatureError < RLSL::Error; end

    class TypeInference
      EXPRESSION_NODES = {
        IR::VarRef => :infer_var_ref,
        IR::Literal => :infer_literal,
        IR::BoolLiteral => :infer_bool_literal,
        IR::BinaryOp => :infer_binary_op,
        IR::UnaryOp => :infer_unary_op,
        IR::FuncCall => :infer_func_call,
        IR::FieldAccess => :infer_field_access,
        IR::Swizzle => :infer_swizzle,
        IR::Parenthesized => :infer_parenthesized,
        IR::ArrayLiteral => :infer_array_literal,
        IR::ArrayIndex => :infer_array_index
      }.freeze

      DEFINITION_NODES = {
        IR::VarDecl => :infer_var_decl,
        IR::Assignment => :infer_assignment,
        IR::GlobalDecl => :infer_global_decl,
        IR::MultipleAssignment => :infer_multiple_assignment
      }.freeze

      CONTROL_FLOW_NODES = {
        IR::IfStatement => :infer_if_statement,
        IR::Ternary => :infer_ternary,
        IR::Return => :infer_return,
        IR::ForLoop => :infer_for_loop,
        IR::WhileLoop => :infer_while_loop,
        IR::FunctionDefinition => :infer_function_definition
      }.freeze

      def initialize(uniforms = {}, custom_functions = {}, globals: {})
        @types = TypeEnvironment.new
        @uniforms = uniforms
        @custom_functions = custom_functions
        @globals = globals
        @inferer_registry = InfererRegistry.new
        @call_validator = CallValidator.new
        @call_type_resolver = CallTypeResolver.new(
          custom_functions: @custom_functions,
          call_validator: @call_validator
        )
        @field_type_resolver = FieldTypeResolver.new(uniforms: @uniforms)
        @collection_type_resolver = CollectionTypeResolver.new(
          type_environment: @types,
          custom_functions: @custom_functions,
          register: method(:register)
        )
        @expression_inferer = ExpressionInferer.new(
          infer: method(:infer),
          lookup: method(:lookup),
          call_type_resolver: @call_type_resolver,
          field_type_resolver: @field_type_resolver,
          collection_type_resolver: @collection_type_resolver
        )
        @definition_inferer = DefinitionInferer.new(
          infer: method(:infer),
          lookup: method(:lookup),
          register: method(:register),
          collection_type_resolver: @collection_type_resolver
        )
        @control_flow_inferer = ControlFlowInferer.new(
          infer: method(:infer),
          infer_in_scope: method(:infer_in_scope),
          lookup: method(:lookup)
        )
        register_inferers

        uniforms.each do |name, type|
          register(name, type)
        end
        register(:u, :uniforms)

        globals.each do |name, type|
          register(name, type)
        end
      end

      def symbol_table
        @types.to_h
      end

      def register(name, type)
        @types.register(name, type)
      end

      def register_function(name, returns:, params: {})
        @custom_functions[name.to_sym] = { returns: returns, params: params }
      end

      def lookup(name)
        @types.lookup(name)
      end

      def infer(node, scoped: false)
        options = node.is_a?(IR::Block) ? { scoped: scoped } : {}
        @inferer_registry.infer(node, **options) || node
      end

      private

      def register_inferers
        @inferer_registry.register(IR::Block) { |node, scoped: false| infer_block(node, scoped: scoped) }
        @inferer_registry.register_methods(@expression_inferer, EXPRESSION_NODES)
        @inferer_registry.register_methods(@definition_inferer, DEFINITION_NODES)
        @inferer_registry.register_methods(@control_flow_inferer, CONTROL_FLOW_NODES)
      end

      def infer_block(node, scoped: false)
        infer_with_optional_scope(scoped) do
          node.statements.each { |stmt| infer(stmt) }
          node.type = node.statements.last&.type
          node
        end
      end

      def infer_child_scope(node)
        infer_in_scope { infer(node) }
      end

      def infer_in_scope(initial_scope = nil)
        initial_scope ? @types.push(initial_scope) : @types.push

        yield
      ensure
        @types.pop
      end

      def infer_with_optional_scope(scoped)
        return yield unless scoped

        @types.push
        yield
      ensure
        @types.pop if scoped
      end
    end
  end
end
