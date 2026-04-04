# frozen_string_literal: true

module RLSL
  class ShaderBuilder
    class SourceResolver
      def initialize(definition, transpiler_class: Prism::Transpiler)
        @definition = definition
        @transpiler_class = transpiler_class
      end

      def sources_for(target)
        [helpers_code(target), fragment_code(target)]
      end

      def helpers_code(target)
        return "" unless @definition.helpers_block
        return @definition.helpers_block.call unless ruby_helpers?

        transpiler.transpile_helpers(@definition.helpers_block, target, @definition.custom_functions)
      end

      def fragment_code(target)
        return "" unless @definition.fragment_block
        return @definition.fragment_block.call unless ruby_fragment?

        transpiler.transpile(@definition.fragment_block, target)
      end

      private

      def transpiler
        @transpiler ||= @transpiler_class.new(@definition.uniforms, @definition.custom_functions)
      end

      def ruby_helpers?
        @definition.ruby_helpers?
      end

      def ruby_fragment?
        @definition.ruby_fragment?
      end
    end
  end
end
