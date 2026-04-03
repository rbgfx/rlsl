# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class MSLEmitter < TargetEmitter
        TYPE_MAP = {
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
        }.freeze

        VECTOR_CONSTRUCTORS = {
          vec2: "float2",
          vec3: "float3",
          vec4: "float4"
        }.freeze

        MATRIX_CONSTRUCTORS = {
          mat2: "float2x2",
          mat3: "float3x3",
          mat4: "float4x4"
        }.freeze

        TEXTURE_FUNCTIONS = {
          texture2D: "sample",
          texture: "sample",
          textureLod: "sample"
        }.freeze

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
