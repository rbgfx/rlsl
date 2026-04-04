# frozen_string_literal: true

require_relative "type_inference/scope_stack"
require_relative "type_inference/type_shapes"
require_relative "type_inference/call_validator"
require_relative "type_inference/type_environment"
require_relative "type_inference/call_type_resolver"
require_relative "type_inference/field_type_resolver"
require_relative "type_inference/collection_type_resolver"

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
        infer(node.initializer) if node.initializer
        node.type ||= node.initializer&.type
        register(node.name, node.type) if node.type
        node
      end

      def infer_var_ref(node)
        node.type ||= lookup(node.name)
        node
      end

      def infer_literal(node)
        node
      end

      def infer_bool_literal(node)
        node.type = :bool
        node
      end

      def infer_binary_op(node)
        infer(node.left)
        infer(node.right)

        node.type = Builtins.binary_op_result_type(
          node.operator,
          node.left.type,
          node.right.type
        )
        node
      end

      def infer_unary_op(node)
        infer(node.operand)

        case node.operator.to_s
        when "-"
          node.type = node.operand.type
        when "!"
          node.type = :bool
        end
        node
      end

      def infer_func_call(node)
        node.args.each { |arg| infer(arg) }
        infer(node.receiver) if node.receiver

        node.type = @call_type_resolver.resolve(node)
        node
      end

      def infer_field_access(node)
        infer(node.receiver)
        node.type = @field_type_resolver.resolve(node)
        node
      end

      def infer_swizzle(node)
        infer(node.receiver)
        node.type = Builtins.swizzle_type(node.components)
        node
      end

      def infer_if_statement(node)
        infer(node.condition)
        infer_child_scope(node.then_branch)
        infer_child_scope(node.else_branch) if node.else_branch

        node.type = node.then_branch.type
        node
      end

      def infer_ternary(node)
        infer(node.condition)
        infer(node.then_expr)
        infer(node.else_expr)
        node.type = node.then_expr.type
        node
      end

      def infer_return(node)
        infer(node.expression) if node.expression
        node.type = node.expression&.type
        node
      end

      def infer_assignment(node)
        infer(node.target)
        infer(node.value)
        node.type = node.value.type
        node
      end

      def infer_for_loop(node)
        infer(node.range_start)
        infer(node.range_end)

        infer_in_scope(node.variable => :int) do
          infer(node.body)
        end

        node.type = nil
        node
      end

      def infer_while_loop(node)
        infer(node.condition)
        infer_child_scope(node.body)
        node.type = nil
        node
      end

      def infer_function_definition(node)
        infer_in_scope(node.param_types) do
          infer(node.body)

          node.return_type ||= node.body&.type
          node.type = node.return_type
        end

        node
      end

      def infer_parenthesized(node)
        infer(node.expression)
        node.type = node.expression.type
        node
      end

      def infer_array_literal(node)
        node.elements.each { |elem| infer(elem) }
        node.type = @collection_type_resolver.resolve_array_literal(node)
        node
      end

      def infer_array_index(node)
        infer(node.array)
        infer(node.index)
        node.type = @collection_type_resolver.resolve_array_index(node)
        node
      end

      def infer_global_decl(node)
        infer(node.initializer) if node.initializer
        node.type ||= @collection_type_resolver.resolve_global_decl(node)
        register(node.name, node.type) if node.type
        node
      end

      def infer_multiple_assignment(node)
        infer(node.value)
        @collection_type_resolver.assign_multiple_targets(node)
        node.type = nil
        node
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
