# frozen_string_literal: true

module RLSL
  module Prism
    class SourceExtractor
      class BlockLocator
        def extract(source, start_line)
          extract_unit(source, start_line).to_source
        end

        def extract_unit(source, start_line, parameters: nil)
          parsed = ::Prism.parse(source)
          raise SourceNotAvailable, "Unable to parse block source" unless parsed.success?

          block = block_at_line(parsed.value, start_line, parameters)
          raise SourceNotAvailable, "Unable to locate block source" unless block

          SourceUnit.from_block(block)
        end

        private

        def block_at_line(node, start_line, parameters)
          candidates = each_node(node).select do |current|
            current.is_a?(::Prism::BlockNode) && current.location.start_line == start_line
          end
          candidates.select! { |candidate| parameter_names(candidate) == required_parameter_names(parameters) } if parameters

          if candidates.length > 1
            raise SourceNotAvailable,
                  "Multiple shader blocks start on line #{start_line}; put each block on its own line"
          end

          candidates.first
        end

        def parameter_names(block)
          return [] unless block.parameters

          block.parameters.parameters.requireds.map(&:name)
        end

        def required_parameter_names(parameters)
          Array(parameters).filter_map { |kind, name| name if kind == :opt || kind == :req }
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
