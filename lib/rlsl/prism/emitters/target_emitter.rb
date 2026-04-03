# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class TargetEmitter < BaseEmitter
        protected

        def type_name(type)
          self.class::TYPE_MAP[type&.to_sym] || default_type_name
        end

        def emit_func_call(node)
          name = node.name.to_sym

          constructor_name = self.class::VECTOR_CONSTRUCTORS[name] || self.class::MATRIX_CONSTRUCTORS[name]
          return emit_named_call(constructor_name, node.args) if constructor_name

          texture_call = emit_texture_call(name, node)
          return texture_call if texture_call

          emit_named_call(name, node.args)
        end

        def emit_binary_op(node)
          left = emit_with_precedence(node.left, node.operator)
          right = emit_with_precedence(node.right, node.operator)
          "#{left} #{node.operator} #{right}"
        end

        def default_type_name
          "float"
        end

        def emit_texture_call(name, node)
          return unless self.class::TEXTURE_FUNCTIONS.key?(name)

          emit_named_call(self.class::TEXTURE_FUNCTIONS[name], node.args)
        end

        def emit_named_call(name, args)
          rendered_args = args.map { |arg| emit(arg) }.join(", ")
          "#{name}(#{rendered_args})"
        end
      end
    end
  end
end
