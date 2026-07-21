# frozen_string_literal: true

module RLSL
  SourceLocation = Struct.new(:source_name, :line, :column, keyword_init: true) do
    def to_s
      "#{source_name || '(shader source)'}:#{line}:#{column}"
    end
  end

  class Error < StandardError
    attr_reader :source_location

    def with_source_location(location)
      @source_location ||= location
      self
    end

    def message
      return super unless source_location

      "#{super} at #{source_location}"
    end
  end
  class InternalError < Error; end
  class ParseError < Error; end
  class TranslationError < Error; end
  class CompilationError < Error; end
  class UniformValueError < ArgumentError; end
end
