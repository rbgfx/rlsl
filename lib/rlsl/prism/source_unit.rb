# frozen_string_literal: true

require_relative "source_unit/parser"
require_relative "parameter_list"

module RLSL
  module Prism
    SourceUnit = Struct.new(:params, :body, keyword_init: true) do
      class << self
        def from_source(source)
          SourceUnitParser.new(source).parse
        end

        def from_block(block)
          new(
            params: extract_params(block),
            body: block.body&.slice.to_s.strip
          )
        end

        private

        def extract_params(block)
          ParameterList.required_names(block.parameters)
        end
      end

      def without_params
        self.class.new(params: [], body: body)
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
