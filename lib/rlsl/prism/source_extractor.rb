# frozen_string_literal: true

require_relative "source_extractor/block_tokenizer"
require_relative "source_extractor/block_capture"

module RLSL
  module Prism
    class SourceExtractor
      class SourceNotAvailable < StandardError; end

      def initialize(block_capture = BlockCapture.new)
        @block_capture = block_capture
      end

      def extract(block)
        file, line_num = block.source_location
        raise SourceNotAvailable, "Block source location not available" unless file && File.exist?(file)

        @block_capture.extract(File.readlines(file), line_num - 1)
      end

      def extract_from_string(source)
        source
      end
    end
  end
end
