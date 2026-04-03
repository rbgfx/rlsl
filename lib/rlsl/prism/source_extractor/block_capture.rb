# frozen_string_literal: true

module RLSL
  module Prism
    class SourceExtractor
      class BlockCapture
        def initialize(tokenizer = BlockTokenizer.new)
          @tokenizer = tokenizer
        end

        def extract(lines, start_line)
          source = +""
          depth = 0
          in_block = false
          block_start_found = false

          lines[start_line..].each_with_index do |line, idx|
            @tokenizer.tokens_for(line).each do |token|
              case token
              when :do, :brace_open
                unless block_start_found
                  block_start_found = true
                  in_block = true
                end
                depth += 1
              when :block_start
                depth += 1
              when :end, :brace_close
                depth -= 1
              end
            end

            next unless block_start_found

            source << (idx == 0 ? extract_first_line(line) : line)
            break if in_block && depth.zero?
          end

          trim_block_source(source)
        end

        private

        def extract_first_line(line)
          return extract_inline_block(line, /do\s*(\|[^|]*\|)?\s*(.*)$/) if line.include?(" do")
          return extract_inline_block(line, /\{\s*(\|[^|]*\|)?\s*(.*)$/) if line.include?("{")

          line
        end

        def extract_inline_block(line, pattern)
          match = line.match(pattern)
          return "\n" unless match

          params = match[1] || ""
          rest = match[2] || ""
          "#{params}\n#{rest}\n"
        end

        def trim_block_source(source)
          lines = source.lines
          return "" if lines.empty?

          last_line = lines.last.strip
          if last_line == "end" || last_line == "}"
            lines.pop
          elsif last_line.end_with?("end") || last_line.end_with?("}")
            lines[-1] = lines[-1].sub(/\s*(end|\})\s*$/, "\n")
          end

          lines.shift if lines.first&.strip&.empty?
          lines.join
        end
      end
    end
  end
end
