# frozen_string_literal: true

module RLSL
  module Prism
    class DefinitionInferer
      def initialize(infer:, register:, collection_type_resolver:)
        @infer = infer
        @register = register
        @collection_type_resolver = collection_type_resolver
      end

      def infer_var_decl(node)
        @infer.call(node.initializer) if node.initializer
        node.type ||= node.initializer&.type
        @register.call(node.name, node.type) if node.type
        node
      end

      def infer_assignment(node)
        @infer.call(node.target)
        @infer.call(node.value)
        node.type = node.value.type
        node
      end

      def infer_global_decl(node)
        @infer.call(node.initializer) if node.initializer
        node.type ||= @collection_type_resolver.resolve_global_decl(node)
        @register.call(node.name, node.type) if node.type
        node
      end

      def infer_multiple_assignment(node)
        @infer.call(node.value)
        @collection_type_resolver.assign_multiple_targets(node)
        node.type = nil
        node
      end
    end
  end
end
