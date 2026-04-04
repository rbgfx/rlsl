# frozen_string_literal: true

require "prism"

module RLSL
  module Prism
    class SourceUnitParser
      def initialize(source)
        @source = source.to_s
      end

      def parse
        normalized = @source.strip
        return SourceUnit.new(params: [], body: "") if normalized.empty?

        params_source, body_source = split_sections(normalized)
        validate_body!(body_source)

        SourceUnit.new(
          params: parse_params(params_source),
          body: body_source.strip
        )
      end

      private

      def split_sections(source)
        lines = source.lines
        first_line = lines.first&.strip
        return [nil, source] unless parameter_line?(first_line)

        [first_line, lines[1..].to_a.join]
      end

      def parameter_line?(line)
        line&.start_with?("|") && line&.end_with?("|")
      end

      def validate_body!(body_source)
        return if body_source.to_s.strip.empty?

        parsed = ::Prism.parse(body_source)
        raise ArgumentError, "Unable to parse source unit body" unless parsed.success?
      end

      def parse_params(params_source)
        return [] unless params_source

        parsed = ::Prism.parse("proc do #{params_source}\nend\n")
        raise ArgumentError, "Unable to parse source unit params" unless parsed.success?

        block = each_node(parsed.value).find { |node| node.is_a?(::Prism::BlockNode) }
        return [] unless block&.parameters

        block.parameters.parameters.requireds.map(&:name)
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
