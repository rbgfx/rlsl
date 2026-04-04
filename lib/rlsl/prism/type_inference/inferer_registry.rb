# frozen_string_literal: true

module RLSL
  module Prism
    class InfererRegistry
      def initialize
        @handlers = {}
      end

      def register(node_class, target = nil, method_name = nil, &block)
        @handlers[node_class] = block || build_handler(target, method_name)
      end

      def register_methods(target, mapping)
        mapping.each do |node_class, method_name|
          register(node_class, target, method_name)
        end
      end

      def infer(node, **options)
        handler = @handlers[node.class]
        return unless handler

        handler.call(node, **options)
      end

      private

      def build_handler(target, method_name)
        lambda do |node, **options|
          return target.send(method_name, node) if options.empty?

          target.send(method_name, node, **options)
        end
      end
    end
  end
end
