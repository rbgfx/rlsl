# frozen_string_literal: true

module RLSL
  module Prism
    module NodeTraversal
      module_function

      def each(node)
        return enum_for(__method__, node) unless block_given?
        return unless node

        stack = [node]
        until stack.empty?
          current = stack.pop
          yield current
          stack.concat(child_nodes(current).reverse)
        end
      end

      def depth_exceeds?(node, maximum)
        return false unless node

        stack = [[node, 1]]
        until stack.empty?
          current, depth = stack.pop
          return true if depth > maximum

          child_nodes(current).reverse_each { |child| stack << [child, depth + 1] }
        end
        false
      end

      def child_nodes(node)
        return node.compact_child_nodes if node.respond_to?(:compact_child_nodes)

        Array(node.child_nodes).compact
      end
      private_class_method :child_nodes
    end
  end
end
