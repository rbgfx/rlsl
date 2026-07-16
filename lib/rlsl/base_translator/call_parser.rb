# frozen_string_literal: true

module RLSL
  class BaseTranslator
    class CallParser
      def self.extract_group(segment, opening_index)
        depth = 0
        index = opening_index
        quote = nil

        while index < segment.length
          char = segment[index]

          if quote
            quote = nil if char == quote && !escaped?(segment, index)
          else
            case char
            when '"', "'"
              quote = char
            when "(", "[", "{"
              depth += 1
            when ")", "]", "}"
              depth -= 1
              return [segment[(opening_index + 1)...index], index] if depth.zero?
            end
          end

          index += 1
        end

        raise ArgumentError, "Unbalanced delimiter in translation source"
      end

      def self.split_arguments(arguments_source)
        arguments = []
        depth = 0
        quote = nil
        start_index = 0

        arguments_source.each_char.with_index do |char, index|
          if quote
            quote = nil if char == quote && !escaped?(arguments_source, index)
            next
          end

          case char
          when '"', "'"
            quote = char
          when "(", "[", "{"
            depth += 1
          when ")", "]", "}"
            depth -= 1
          when ","
            next unless depth.zero?

            arguments << arguments_source[start_index...index]
            start_index = index + 1
          end
        end

        tail = arguments_source[start_index..]
        return [] if arguments.empty? && tail.to_s.strip.empty?

        arguments << tail
      end

      def self.escaped?(source, index)
        backslashes = 0
        cursor = index - 1
        while cursor >= 0 && source[cursor] == "\\"
          backslashes += 1
          cursor -= 1
        end

        backslashes.odd?
      end
    end
  end
end
