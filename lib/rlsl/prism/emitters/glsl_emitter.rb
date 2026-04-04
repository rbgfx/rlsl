# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class GLSLEmitter < TargetEmitter
        PROFILE = TargetProfile.new(
          type_map: {
            float: "float",
            int: "int",
            bool: "bool",
            vec2: "vec2",
            vec3: "vec3",
            vec4: "vec4",
            mat2: "mat2",
            mat3: "mat3",
            mat4: "mat4",
            sampler2D: "sampler2D"
          },
          vector_constructors: {
            vec2: "vec2",
            vec3: "vec3",
            vec4: "vec4"
          },
          matrix_constructors: {
            mat2: "mat2",
            mat3: "mat3",
            mat4: "mat4"
          },
          texture_functions: {
            texture2D: "texture2D",
            texture: "texture",
            textureLod: "textureLod"
          }
        ).freeze

        TYPE_MAP = PROFILE.type_map
        VECTOR_CONSTRUCTORS = PROFILE.vector_constructors
        MATRIX_CONSTRUCTORS = PROFILE.matrix_constructors
        TEXTURE_FUNCTIONS = PROFILE.texture_functions
      end
    end
  end
end
