# frozen_string_literal: true

require_relative "source_unit/parser"
require_relative "parameter_list"

module RLSL
  module Prism
    SourceUnit = Struct.new(:params, :body, :source_name, :line_offset, keyword_init: true) do
      class << self
        def from_source(source, source_name: "(shader source)")
          SourceUnitParser.new(source, source_name: source_name).parse
        end

        def from_block(block, source_name: "(shader block)")
          new(
            params: extract_params(block),
            body: block.body&.slice.to_s.strip,
            source_name: source_name,
            line_offset: block.body ? block.body.location.start_line - 1 : block.location.start_line - 1
          )
        end

        private

        def extract_params(block)
          ParameterList.required_names(block.parameters)
        end
      end

      def without_params
        self.class.new(params: [], body: body, source_name: source_name, line_offset: line_offset)
      end

      def to_source
        segments = []
        segments << "|#{params.join(', ')}|" unless params.empty?
        segments << body unless body.empty?
        segments.join("\n")
      end
    end
  end
end
