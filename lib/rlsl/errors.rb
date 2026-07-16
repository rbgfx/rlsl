# frozen_string_literal: true

module RLSL
  class Error < StandardError; end
  class ParseError < Error; end
  class CompilationError < Error; end
end
