# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class MSLEmitter < TargetEmitter
        PROFILE = TargetProfile.new(
          type_map: {
            float: "float",
            int: "int",
            bool: "bool",
            vec2: "float2",
            vec3: "float3",
            vec4: "float4",
            mat2: "float2x2",
            mat3: "float3x3",
            mat4: "float4x4",
            sampler2D: "texture2d<float>"
          },
          vector_constructors: {
            vec2: "float2",
            vec3: "float3",
            vec4: "float4"
          },
          matrix_constructors: {
            mat2: "float2x2",
            mat3: "float3x3",
            mat4: "float4x4"
          },
          texture_functions: {
            texture2D: "sample",
            texture: "sample",
            textureLod: "sample"
          }
        ).freeze

        TYPE_MAP = PROFILE.type_map
        VECTOR_CONSTRUCTORS = PROFILE.vector_constructors
        MATRIX_CONSTRUCTORS = PROFILE.matrix_constructors
        TEXTURE_FUNCTIONS = PROFILE.texture_functions
        protected

        def emit_texture_call(name, node)
          return unless TEXTURE_FUNCTIONS.key?(name) && node.args.length >= 2

          texture = emit(node.args[0])
          uv = emit(node.args[1])
          "#{texture}.sample(textureSampler, #{uv})"
        end
      end
    end
  end
end
