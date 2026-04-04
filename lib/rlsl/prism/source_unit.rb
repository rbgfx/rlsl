# frozen_string_literal: true

module RLSL
  module Prism
    SourceUnit = Struct.new(:params, :body, keyword_init: true) do
      class << self
        def from_source(source)
          parsed = ::Prism.parse(wrap(source))
          raise ArgumentError, "Unable to parse source unit" unless parsed.success?

          block = find_block(parsed.value)
          raise ArgumentError, "Unable to locate source unit block" unless block

          from_block(block)
        end

        def from_block(block)
          new(
            params: extract_params(block),
            body: block.body&.slice.to_s.strip
          )
        end

        private

        def wrap(source)
          stripped = source.to_s.strip
          return "proc do\nend\n" if stripped.empty?
          return "proc do #{stripped}\nend\n" if stripped.start_with?("|")

          "proc do\n#{stripped}\nend\n"
        end

        def find_block(node)
          each_node(node).find { |current| current.is_a?(::Prism::BlockNode) }
        end

        def extract_params(block)
          return [] unless block.parameters

          parameters = block.parameters.parameters
          parameters.requireds.map(&:name)
        end

        def each_node(node)
          return enum_for(:each_node, node) unless block_given?
          return unless node

          stack = [node]

          until stack.empty?
            current = stack.pop
            yield current

            children = if current.respond_to?(:compact_child_nodes)
                         current.compact_child_nodes
                       else
                         Array(current.child_nodes).compact
                       end
            stack.concat(children.reverse)
          end
        end
      end

      def without_params
        self.class.new(params: [], body: body)
      end

      def to_source
        segments = []
        segments << "|#{params.join(', ')}|" unless params.empty?
        segments << body unless body.empty?
        segments.join("\n")
      end
    end
  end
end
