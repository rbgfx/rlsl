# frozen_string_literal: true

require_relative "call_parser"
require_relative "code_scanner"

module RLSL
  class BaseTranslator
    class CodeRewriter
      IDENTIFIER_PATTERN = /[A-Za-z_][A-Za-z0-9_]*/

      def initialize(code)
        @code = code.to_s
      end

      def rewrite(identifier_replacements:, call_rewrites:, removed_identifiers:)
        rewrite_segment(
          @code,
          identifier_replacements: stringify_keys(identifier_replacements),
          call_rewrites: stringify_keys(call_rewrites),
          removed_identifiers: Array(removed_identifiers).map(&:to_s)
        )
      end

      private

      def rewrite_segment(segment, identifier_replacements:, call_rewrites:, removed_identifiers:)
        CodeScanner.new(segment).each_segment.map do |code_segment|
          code_segment.code? ? rewrite_code_segment(
            code_segment.text,
            identifier_replacements: identifier_replacements,
            call_rewrites: call_rewrites,
            removed_identifiers: removed_identifiers
          ) : code_segment.text
        end.join
      end

      def rewrite_code_segment(segment, identifier_replacements:, call_rewrites:, removed_identifiers:)
        output = +""
        index = 0

        while index < segment.length
          if identifier_start?(segment, index)
            identifier, identifier_end = read_identifier(segment, index)
            call_index = skip_whitespace(segment, identifier_end)

            if call_rewrites.key?(identifier) && segment[call_index] == "("
              arguments_source, closing_index = CallParser.extract_group(segment, call_index)
              rewritten_args = CallParser.split_arguments(arguments_source).map do |argument|
                rewrite_segment(
                  argument,
                  identifier_replacements: identifier_replacements,
                  call_rewrites: call_rewrites,
                  removed_identifiers: removed_identifiers
                ).strip
              end
              output << render_call(call_rewrites.fetch(identifier), rewritten_args)
              index = closing_index + 1
              next
            end

            unless removed_identifiers.include?(identifier)
              output << (identifier_replacements[identifier] || identifier)
            end
            index = identifier_end
            next
          end

          output << segment[index]
          index += 1
        end

        output
      end

      def render_call(rewriter, arguments)
        return rewriter.call(arguments) if rewriter.respond_to?(:call)

        "#{rewriter}(#{arguments.join(', ')})"
      end

      def stringify_keys(hash)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value
        end
      end

      def identifier_start?(segment, index)
        segment[index] =~ /[A-Za-z_]/
      end

      def read_identifier(segment, index)
        match = IDENTIFIER_PATTERN.match(segment, index)
        [match[0], match.end(0)]
      end

      def skip_whitespace(segment, index)
        current_index = index
        current_index += 1 while current_index < segment.length && whitespace?(segment[current_index])
        current_index
      end

      def whitespace?(char)
        char =~ /\s/
      end
    end
  end
end
