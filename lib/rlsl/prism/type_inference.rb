# frozen_string_literal: true

require_relative "type_inference/scope_stack"
require_relative "type_inference/type_shapes"
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
    class SignatureError < StandardError; end

    class TypeInference
      INFERERS = {
        IR::Block => :infer_block,
        IR::VarDecl => :infer_var_decl,
        IR::VarRef => :infer_var_ref,
        IR::Literal => :infer_literal,
        IR::BoolLiteral => :infer_bool_literal,
        IR::BinaryOp => :infer_binary_op,
        IR::UnaryOp => :infer_unary_op,
        IR::FuncCall => :infer_func_call,
        IR::FieldAccess => :infer_field_access,
        IR::Swizzle => :infer_swizzle,
        IR::IfStatement => :infer_if_statement,
        IR::Ternary => :infer_ternary,
        IR::Return => :infer_return,
        IR::Assignment => :infer_assignment,
        IR::ForLoop => :infer_for_loop,
        IR::WhileLoop => :infer_while_loop,
        IR::Parenthesized => :infer_parenthesized,
        IR::FunctionDefinition => :infer_function_definition,
        IR::ArrayLiteral => :infer_array_literal,
        IR::ArrayIndex => :infer_array_index,
        IR::GlobalDecl => :infer_global_decl,
        IR::MultipleAssignment => :infer_multiple_assignment
      }.freeze

      def initialize(uniforms = {}, custom_functions = {})
        @types = TypeEnvironment.new
        @uniforms = uniforms
        @custom_functions = custom_functions
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
          register: method(:register),
          collection_type_resolver: @collection_type_resolver
        )
        @control_flow_inferer = ControlFlowInferer.new(
          infer: method(:infer),
          infer_child_scope: method(:infer_child_scope),
          infer_in_scope: method(:infer_in_scope)
        )

        uniforms.each do |name, type|
          register(name, type)
        end
      end

      def symbol_table
        @types.to_h
      end

      def register(name, type)
        @types.register(name, type)
      end

      def register_function(name, returns:)
        @custom_functions[name.to_sym] = { returns: returns }
      end

      def lookup(name)
        @types.lookup(name)
      end

      def infer(node, scoped: false)
        inferer = INFERERS[node.class]
        return node unless inferer

        return infer_block(node, scoped: scoped) if inferer == :infer_block

        send(inferer, node)
      end

      private

      def infer_block(node, scoped: false)
        infer_with_optional_scope(scoped) do
          node.statements.each { |stmt| infer(stmt) }
          node.type = node.statements.last&.type
          node
        end
      end

      def infer_var_decl(node)
        @definition_inferer.infer_var_decl(node)
      end

      def infer_var_ref(node)
        @expression_inferer.infer_var_ref(node)
      end

      def infer_literal(node)
        @expression_inferer.infer_literal(node)
      end

      def infer_bool_literal(node)
        @expression_inferer.infer_bool_literal(node)
      end

      def infer_binary_op(node)
        @expression_inferer.infer_binary_op(node)
      end

      def infer_unary_op(node)
        @expression_inferer.infer_unary_op(node)
      end

      def infer_func_call(node)
        @expression_inferer.infer_func_call(node)
      end

      def infer_field_access(node)
        @expression_inferer.infer_field_access(node)
      end

      def infer_swizzle(node)
        @expression_inferer.infer_swizzle(node)
      end

      def infer_if_statement(node)
        @control_flow_inferer.infer_if_statement(node)
      end

      def infer_ternary(node)
        @control_flow_inferer.infer_ternary(node)
      end

      def infer_return(node)
        @control_flow_inferer.infer_return(node)
      end

      def infer_assignment(node)
        @definition_inferer.infer_assignment(node)
      end

      def infer_for_loop(node)
        @control_flow_inferer.infer_for_loop(node)
      end

      def infer_while_loop(node)
        @control_flow_inferer.infer_while_loop(node)
      end

      def infer_function_definition(node)
        @control_flow_inferer.infer_function_definition(node)
      end

      def infer_parenthesized(node)
        @expression_inferer.infer_parenthesized(node)
      end

      def infer_array_literal(node)
        @expression_inferer.infer_array_literal(node)
      end

      def infer_array_index(node)
        @expression_inferer.infer_array_index(node)
      end

      def infer_global_decl(node)
        @definition_inferer.infer_global_decl(node)
      end

      def infer_multiple_assignment(node)
        @definition_inferer.infer_multiple_assignment(node)
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
