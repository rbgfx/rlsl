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

      def translation_sources_for(target)
        [helpers_source(target), fragment_source(target)]
      end

      def helpers_code(target)
        helpers_source(target).code
      end

      def fragment_code(target)
        fragment_source(target).code
      end

      private

      def helpers_source(target)
        return source_snippet("") unless @definition.helpers_block
        return source_snippet(@definition.helpers_block.call) unless ruby_helpers?

        source_snippet(
          transpiler.transpile_helpers(@definition.helpers_block, target, @definition.custom_functions),
          format: :target
        )
      end

      def fragment_source(target)
        return source_snippet("") unless @definition.fragment_block
        return source_snippet(@definition.fragment_block.call) unless ruby_fragment?

        source_snippet(transpiler.transpile(@definition.fragment_block, target), format: :target)
      end

      def source_snippet(code, format: :legacy)
        BaseTranslator::SourceSnippet.new(code: code.to_s, format: format)
      end

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
