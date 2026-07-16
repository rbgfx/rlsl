# frozen_string_literal: true

module RLSL
  class CodeGenerator
    class UniformStructGenerator
      def initialize(context)
        @context = context
      end

      def generate
        return "typedef struct { unsigned char _unused; } Uniforms;\n" if @context.uniform_entries.empty?

        <<~C
          typedef struct {
          #{field_lines}
          } Uniforms;
        C
      end

      private

      def field_lines
        @context.uniform_entries.map do |uniform_name, spec|
          "  #{spec.c_type} #{uniform_name};"
        end.join("\n")
      end
    end
  end
end
