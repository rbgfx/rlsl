# frozen_string_literal: true

require_relative "target_profile"

module RLSL
  module Prism
    module Emitters
      class TargetEmitter < BaseEmitter
        protected

        def type_name(type)
          profile.type_map[type&.to_sym] || default_type_name
        end

        def emit_func_call(node)
          resolved_call = emit_profile_call(node)
          return resolved_call if resolved_call

          name = node.name.to_sym

          constructor_name = profile.vector_constructors[name] || profile.matrix_constructors[name]
          if constructor_name
            return emit_named_call(constructor_name, node.args, expected_types: Array.new(node.args.length, :float))
          end

          texture_call = emit_texture_call(name, node)
          return texture_call if texture_call

          math_function = profile.math_functions[name]
          return emit_named_call(math_function, node.args, expected_types: node.expected_arg_types) if math_function

          emit_named_call(name, node.args, receiver: node.receiver, expected_types: node.expected_arg_types)
        end

        def emit_binary_op(node)
          resolved_binary_op = emit_profile_binary_op(node)
          return resolved_binary_op if resolved_binary_op
          return emit_promoted_binary_op(node) if needs_float_promotion?(node)

          left = emit_with_precedence(node.left, node.operator, side: :left)
          right = emit_with_precedence(node.right, node.operator, side: :right)
          "#{left} #{node.operator} #{right}"
        end

        def default_type_name
          profile.default_type_name
        end

        def emit_texture_call(name, node)
          return unless profile.texture_functions.key?(name)

          emit_named_call(profile.texture_functions[name], node.args, expected_types: node.expected_arg_types)
        end

        def emit_named_call(name, args, receiver: nil, expected_types: [])
          rendered_args = []
          rendered_args << emit_typed_argument(receiver, expected_types.first) if receiver
          offset = receiver ? 1 : 0
          rendered_args.concat(args.each_with_index.map do |arg, index|
            emit_typed_argument(arg, expected_types[index + offset])
          end)
          "#{name}(#{rendered_args.join(', ')})"
        end

        def emit_typed_argument(node, expected_type)
          return emit_float_operand(node) if expected_type == :float

          emit(node)
        end

        def needs_float_promotion?(node)
          types = [node.left.type, node.right.type]
          return true if node.operator == "/" && types.all?(:int)

          types.include?(:int) && types.any? { |type| type == :float || Builtins.vector_type?(type) || Builtins.matrix_type?(type) }
        end

        def emit_promoted_binary_op(node)
          left = emit_promoted_operand(node.left, node.operator, :left)
          right = emit_promoted_operand(node.right, node.operator, :right)
          "#{left} #{node.operator} #{right}"
        end

        def emit_float_operand(node)
          return emit(node) unless node.type == :int

          "#{type_name(:float)}(#{emit(node)})"
        end

        def emit_promoted_operand(node, operator, side)
          return emit_float_operand(node) if node.type == :int

          emit_with_precedence(node, operator, side: side)
        end

        def emit_profile_call(node)
          return unless profile.call_resolver

          send(profile.call_resolver, node)
        end

        def emit_profile_binary_op(node)
          return unless profile.binary_op_resolver

          send(profile.binary_op_resolver, node)
        end

        def profile
          self.class::PROFILE
        end
      end
    end
  end
end
