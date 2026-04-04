# frozen_string_literal: true

module RLSL
  class ShaderBuilder
    class SourceResolver
      def initialize(uniforms:, custom_functions:, helpers_block:, helpers_mode:, fragment_block:, fragment_mode:)
        @uniforms = uniforms
        @custom_functions = custom_functions
        @helpers_block = helpers_block
        @helpers_mode = helpers_mode
        @fragment_block = fragment_block
        @fragment_mode = fragment_mode
      end

      def sources_for(target)
        [helpers_code(target), fragment_code(target)]
      end

      def helpers_code(target)
        return "" unless @helpers_block
        return @helpers_block.call unless ruby_helpers?

        transpiler.transpile_helpers(@helpers_block, target, @custom_functions)
      end

      def fragment_code(target)
        return "" unless @fragment_block
        return @fragment_block.call unless ruby_fragment?

        transpiler.transpile(@fragment_block, target)
      end

      private

      def transpiler
        @transpiler ||= Prism::Transpiler.new(@uniforms, @custom_functions)
      end

      def ruby_helpers?
        @helpers_mode == :ruby
      end

      def ruby_fragment?
        @fragment_mode == :ruby
      end
    end
  end
end
