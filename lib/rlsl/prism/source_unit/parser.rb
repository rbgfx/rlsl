# frozen_string_literal: true

require "prism"

require_relative "../node_traversal"
require_relative "../parameter_list"

module RLSL
  module Prism
    class SourceUnitParser
      def initialize(source, source_name: "(shader source)")
        @source = source.to_s
        @source_name = source_name
      end

      def parse
        normalized, leading_line_offset = strip_with_line_offset(@source)
        if normalized.empty?
          return SourceUnit.new(params: [], body: "", source_name: @source_name, line_offset: leading_line_offset)
        end

        params_source, body_source, parameter_line_offset = split_sections(normalized)
        stripped_body, body_line_offset = strip_with_line_offset(body_source)
        line_offset = leading_line_offset + parameter_line_offset + body_line_offset
        validate_body!(stripped_body, line_offset)

        SourceUnit.new(
          params: parse_params(params_source),
          body: stripped_body,
          source_name: @source_name,
          line_offset: line_offset
        )
      end

      private

      def split_sections(source)
        lines = source.lines
        first_line = lines.first&.strip
        return [nil, source, 0] unless parameter_line?(first_line)

        [first_line, lines[1..].to_a.join, 1]
      end

      def parameter_line?(line)
        line&.start_with?("|") && line.end_with?("|")
      end

      def validate_body!(body_source, line_offset)
        return if body_source.to_s.strip.empty?

        parsed = ::Prism.parse(body_source)
        return if parsed.success?

        error = RLSL::ParseError.new("Unable to parse source unit body")
        location = parsed.errors.first&.location
        if location
          error.with_source_location(
            RLSL::SourceLocation.new(
              source_name: @source_name,
              line: line_offset + location.start_line,
              column: location.start_column + 1
            )
          )
        end
        raise error
      end

      def parse_params(params_source)
        return [] unless params_source

        parsed = ::Prism.parse("proc do #{params_source}\nend\n")
        raise RLSL::ParseError, "Unable to parse source unit params" unless parsed.success?

        block = NodeTraversal.each(parsed.value).find { |node| node.is_a?(::Prism::BlockNode) }
        return [] unless block

        ParameterList.required_names(block.parameters)
      end

      def strip_with_line_offset(source)
        text = source.to_s
        leading_whitespace = text[/\A\s*/].to_s
        [text.strip, leading_whitespace.count("\n")]
      end
    end
  end
end
