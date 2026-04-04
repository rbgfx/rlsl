# frozen_string_literal: true

module RLSL
  class CodeGenerator
    class ShaderFunctionGenerator
      def initialize(context)
        @context = context
      end

      def generate
        <<~C
          static vec3 shader_#{@context.name}(vec2 frag_coord, vec2 resolution, Uniforms u) {
            #{@context.fragment_code}
          }
        C
      end
    end
  end
end
