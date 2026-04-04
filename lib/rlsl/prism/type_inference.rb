# frozen_string_literal: true

require_relative "type_inference/scope_stack"
require_relative "type_inference/type_shapes"
require_relative "type_inference/call_validator"
require_relative "type_inference/type_environment"

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

        sig = Builtins.function_signature(node.name)
        if sig
          arg_types = node.args.map(&:type)
          @call_validator.validate_builtin!(node, arg_types, sig)
          node.type = Builtins.resolve_return_type(sig[:returns], arg_types)
        elsif @custom_functions.key?(node.name.to_sym)
          @call_validator.validate_custom!(node.name, node.args.map(&:type), @custom_functions[node.name.to_sym])
          node.type = @custom_functions[node.name.to_sym][:returns]
        else
          node.type = node.receiver&.type
        end
        node
      end

      def infer_field_access(node)
        infer(node.receiver)

        if Builtins.single_component_field?(node.field)
          node.type = :float
        else
          node.type = @uniforms[node.field.to_sym] || :float
        end
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

        element_type = node.elements.first&.type || :float
        node.type = TypeShapes.array(element_type)
        node
      end

      def infer_array_index(node)
        infer(node.array)
        infer(node.index)

        array_type = node.array.type
        if TypeShapes.array?(array_type)
          node.type = TypeShapes.element_type(array_type)
        elsif node.array.is_a?(IR::VarRef)
          node.type = @types.array_element_type(node.array.name) || :float
        else
          node.type = :float
        end
        node
      end

      def infer_global_decl(node)
        infer(node.initializer) if node.initializer

        if node.initializer.is_a?(IR::ArrayLiteral)
          node.array_size ||= node.initializer.elements.length
          first_elem = node.initializer.elements.first
          node.element_type ||= first_elem&.type || :float
          node.type = TypeShapes.array(node.element_type)
        else
          node.type ||= node.initializer&.type
        end

        register(node.name, node.type) if node.type
        node
      end

      def infer_multiple_assignment(node)
        infer(node.value)

        value_type = node.value.type
        if value_type.is_a?(IR::TupleType)
          node.targets.each_with_index do |target, i|
            target.type = value_type.types[i]
            register(target.name, target.type)
          end
        elsif TypeShapes.array?(value_type)
          elem_type = TypeShapes.element_type(value_type)
          node.targets.each do |target|
            target.type = elem_type
            register(target.name, target.type)
          end
        elsif node.value.is_a?(IR::FuncCall) && @custom_functions.key?(node.value.name)
          func_info = @custom_functions[node.value.name]
          if func_info[:returns].is_a?(Array)
            node.targets.each_with_index do |target, i|
              target.type = func_info[:returns][i]
              register(target.name, target.type)
            end
          end
        end

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
