# frozen_string_literal: true

module RLSL
  class BaseTranslator
    class CodeScanner
      Segment = Struct.new(:type, :text, keyword_init: true) do
        def code?
          type == :code
        end
      end

      def initialize(code)
        @code = code.to_s
      end

      def each_segment
        return enum_for(:each_segment) unless block_given?

        buffer = +""
        index = 0

        while index < @code.length
          preserved, next_index = read_preserved_segment(index)
          unless preserved
            buffer << @code[index]
            index += 1
            next
          end

          yield Segment.new(type: :code, text: buffer) unless buffer.empty?
          buffer = +""
          yield Segment.new(type: preserved[:type], text: preserved[:text])
          index = next_index
        end

        yield Segment.new(type: :code, text: buffer) unless buffer.empty?
      end

      private

      def read_preserved_segment(index)
        if line_comment_start?(index)
          comment, next_index = read_line_comment(index)
          return [{ type: :line_comment, text: comment }, next_index]
        end

        if block_comment_start?(index)
          comment, next_index = read_block_comment(index)
          return [{ type: :block_comment, text: comment }, next_index]
        end

        if string_delimiter?(@code[index])
          literal, next_index = read_quoted(index)
          return [{ type: :string, text: literal }, next_index]
        end

        nil
      end

      def line_comment_start?(index)
        @code[index, 2] == "//"
      end

      def block_comment_start?(index)
        @code[index, 2] == "/*"
      end

      def string_delimiter?(char)
        char == '"' || char == "'"
      end

      def read_line_comment(index)
        newline_index = @code.index("\n", index)
        end_index = newline_index ? newline_index : @code.length
        [@code[index...end_index], end_index]
      end

      def read_block_comment(index)
        closing_index = @code.index("*/", index + 2)
        raise ArgumentError, "Unterminated block comment in translation source" unless closing_index

        end_index = closing_index + 2
        [@code[index...end_index], end_index]
      end

      def read_quoted(index)
        quote = @code[index]
        cursor = index + 1

        while cursor < @code.length
          if @code[cursor] == quote && @code[cursor - 1] != "\\"
            return [@code[index..cursor], cursor + 1]
          end

          cursor += 1
        end

        raise ArgumentError, "Unterminated string literal in translation source"
      end
    end
  end
end
