# frozen_string_literal: true

require_relative "../node_traversal"
require_relative "../parameter_list"

module RLSL
  module Prism
    class SourceExtractor
      class BlockLocator
        def extract(source, start_line)
          extract_unit(source, start_line).to_source
        end

        def extract_unit(source, start_line, parameters: nil, source_name: "(shader block)")
          parsed = ::Prism.parse(source)
          raise SourceNotAvailable, "Unable to parse block source" unless parsed.success?

          block = block_at_line(parsed.value, start_line, parameters)
          raise SourceNotAvailable, "Unable to locate block source" unless block

          SourceUnit.from_block(block, source_name: source_name)
        end

        private

        def block_at_line(node, start_line, parameters)
          candidates = NodeTraversal.each(node).select do |current|
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
          ParameterList.names(block.parameters)
        end

        def required_parameter_names(parameters)
          Array(parameters).filter_map { |_kind, name| name }
        end
      end
    end
  end
end
