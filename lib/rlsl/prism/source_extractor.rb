# frozen_string_literal: true

require "prism"

require_relative "source_unit"
require_relative "source_extractor/block_locator"

module RLSL
  module Prism
    class SourceExtractor
      class SourceNotAvailable < RLSL::Error; end

      def initialize(block_locator = BlockLocator.new)
        @block_locator = block_locator
      end

      def extract(block)
        extract_unit(block).to_source
      end

      def extract_unit(block)
        file, line_num = block.source_location
        raise SourceNotAvailable, "Block source location not available" unless file && File.exist?(file)

        @block_locator.extract_unit(File.read(file), line_num, parameters: block.parameters)
      end

      def extract_from_string(source)
        source
      end
    end
  end
end
