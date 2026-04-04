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
          helpers_transpiler.transpile_helpers(@definition.helpers_block, target, @definition.custom_functions),
          format: :target
        )
      end

      def fragment_source(target)
        return source_snippet("") unless @definition.fragment_block
        return source_snippet(@definition.fragment_block.call) unless ruby_fragment?

        source_snippet(fragment_transpiler.transpile(@definition.fragment_block, target), format: :target)
      end

      def source_snippet(code, format: :legacy)
        BaseTranslator::SourceSnippet.new(code: code.to_s, format: format)
      end

      def helpers_transpiler
        @helpers_transpiler ||= build_transpiler
      end

      def fragment_transpiler
        @fragment_transpiler ||= build_transpiler(globals: helper_globals)
      end

      def build_transpiler(globals: {})
        @transpiler_class.new(@definition.uniforms, @definition.custom_functions, globals: globals)
      end

      def helper_globals
        return {} unless ruby_helpers? && @definition.helpers_block

        @helper_globals ||= begin
          compilation = helpers_transpiler.compile_helpers(@definition.helpers_block, @definition.custom_functions)
          extract_global_types(compilation.ir)
        end
      end

      def extract_global_types(ir)
        return {} unless ir.is_a?(Prism::IR::Block)

        ir.statements.each_with_object({}) do |statement, globals|
          next unless statement.is_a?(Prism::IR::GlobalDecl)
          next unless statement.type

          globals[statement.name] = statement.type
        end
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
