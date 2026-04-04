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
            quote = nil if char == quote && segment[index - 1] != "\\"
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
            quote = nil if char == quote && arguments_source[index - 1] != "\\"
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
    end
  end
end
