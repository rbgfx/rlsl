# frozen_string_literal: true

module RLSL
  module Prism
    class SourceExtractor
      class BlockTokenizer
        def tokens_for(line)
          tokens = []
          in_string = nil
          i = 0

          while i < line.length
            char = line[i]

            if in_string
              in_string = nil if char == in_string && (i == 0 || line[i - 1] != "\\")
              i += 1
              next
            end

            if char == '"' || char == "'"
              in_string = char
              i += 1
              next
            end

            break if char == "#"

            prev_is_boundary = i == 0 || !line[i - 1].match?(/[a-zA-Z0-9_]/)

            if char == "{"
              tokens << :brace_open
            elsif char == "}"
              tokens << :brace_close
            elsif prev_is_boundary && line[i..].match?(/\Ado\b/)
              tokens << :do
              i += 1
            elsif prev_is_boundary && line[i..].match?(/\Aelsif\b/)
              i += 4
            elsif prev_is_boundary && line[i..].match?(/\Aelse\b/)
              i += 3
            elsif prev_is_boundary && (match = line[i..].match(/\A(if|unless|while|for|case|def|class|module)\b/))
              token = block_token(line, i, match[1])
              tokens << token if token
              i += match[1].length - 1
            elsif prev_is_boundary && line[i..].match?(/\Aend\b/)
              tokens << :end
              i += 2
            end

            i += 1
          end

          tokens
        end

        private

        def block_token(line, index, keyword)
          has_code_before = line[0...index].match?(/\S/)
          return :block_start unless has_code_before && %w[if unless while].include?(keyword)

          previous_token = line[0...index].rstrip[-1]
          previous_token == "=" ? :block_start : nil
        end
      end
    end
  end
end
