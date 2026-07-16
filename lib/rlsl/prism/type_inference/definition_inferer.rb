# frozen_string_literal: true

module RLSL
  module Prism
    class DefinitionInferer
      def initialize(infer:, lookup:, register:, collection_type_resolver:)
        @infer = infer
        @lookup = lookup
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
        existing_type = node.target.is_a?(IR::VarRef) ? @lookup.call(node.target.name) : node.target.type
        if existing_type && node.value.type && !compatible_assignment?(existing_type, node.value.type)
          raise SignatureError,
                "Cannot assign #{node.value.type} to #{node.target.name} (#{existing_type})"
        end

        node.target.type ||= node.value.type
        @register.call(node.target.name, node.value.type) if node.target.is_a?(IR::VarRef) && !existing_type
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

      private

      def compatible_assignment?(target_type, value_type)
        target_type == value_type || (target_type == :float && value_type == :int)
      end
    end
  end
end
