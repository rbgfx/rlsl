# frozen_string_literal: true

module RLSL
  class CodeGenerator
    class TemplateContext
      attr_reader :name, :extension_name

      def initialize(name:, uniforms:, helpers_block:, fragment_block:, extension_name: name)
        @name = RLSL.validate_shader_name!(name)
        @extension_name = RLSL.validate_identifier!(extension_name, context: "extension name")
        @uniforms = uniforms
        @helpers_block = helpers_block
        @fragment_block = fragment_block
      end

      def render_arity
        3 + @uniforms.size
      end

      def helpers_code
        return "" unless @helpers_block

        @helpers_block.call
      end

      def fragment_code
        return "" unless @fragment_block

        @fragment_block.call
      end

      def uniform_entries
        @uniform_entries ||= @uniforms.map do |uniform_name, type|
          [uniform_name, UniformTypes.compiled_spec(type)]
        end
      end

      def uniform_argument_list
        arguments = @uniforms.map { |uniform_name, _| "VALUE rb_#{uniform_name}" }
        arguments.empty? ? "" : ", #{arguments.join(', ')}"
      end
    end
  end
end
