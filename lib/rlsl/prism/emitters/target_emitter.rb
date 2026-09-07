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
          return emit_named_call(constructor_name, node.args) if constructor_name

          texture_call = emit_texture_call(name, node)
          return texture_call if texture_call

          math_function = profile.math_functions[name]
          return emit_named_call(math_function, node.args) if math_function

          emit_named_call(name, node.args, receiver: node.receiver)
        end

        def emit_binary_op(node)
          return emit_integer_division(node) if integer_division?(node)

          resolved_binary_op = emit_profile_binary_op(node)
          return resolved_binary_op if resolved_binary_op

          left = emit_with_precedence(node.left, node.operator, side: :left)
          right = emit_with_precedence(node.right, node.operator, side: :right)
          "#{left} #{node.operator} #{right}"
        end

        def default_type_name
          profile.default_type_name
        end

        def emit_texture_call(name, node)
          return unless profile.texture_functions.key?(name)

          emit_named_call(profile.texture_functions[name], node.args)
        end

        def emit_named_call(name, args, receiver: nil)
          rendered_args = []
          rendered_args << emit(receiver) if receiver
          rendered_args.concat(args.map { |arg| emit(arg) })
          "#{name}(#{rendered_args.join(', ')})"
        end

        def integer_division?(node)
          node.operator == "/" && node.left.type == :int && node.right.type == :int && node.type == :float
        end

        def emit_integer_division(node)
          type = type_name(:float)
          "#{type}(#{emit(node.left)}) / #{type}(#{emit(node.right)})"
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
