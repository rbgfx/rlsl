# frozen_string_literal: true

module RLSL
  module Prism
    class SourceExtractor
      class BlockLocator
        def extract(source, start_line)
          parsed = ::Prism.parse(source)
          raise SourceNotAvailable, "Unable to parse block source" unless parsed.success?

          block = block_at_line(parsed.value, start_line)
          raise SourceNotAvailable, "Unable to locate block source" unless block

          normalize(block)
        end

        private

        def block_at_line(node, start_line)
          each_node(node) do |current|
            next unless current.is_a?(::Prism::BlockNode)
            return current if current.location.start_line == start_line
          end

          nil
        end

        def normalize(block)
          parts = []
          params = block.parameters&.slice
          body = block.body&.slice.to_s

          parts << params if params && !params.empty?
          parts << body unless body.empty?

          parts.join("\n")
        end

        def each_node(node)
          return enum_for(:each_node, node) unless block_given?
          return unless node

          stack = [node]

          until stack.empty?
            current = stack.pop
            yield current

            children = if current.respond_to?(:compact_child_nodes)
                         current.compact_child_nodes
                       else
                         Array(current.child_nodes).compact
                       end
            stack.concat(children.reverse)
          end
        end
      end
    end
  end
end
