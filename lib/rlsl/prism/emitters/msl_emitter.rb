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

        protected

        def emit_texture_call(name, node)
          return unless profile.texture_functions.key?(name) && node.args.length >= 2

          texture = emit(node.args[0])
          uv = emit(node.args[1])
          if name == :textureLod
            lod = emit(node.args[2])
            return "#{texture}.sample(rlsl_texture_sampler, #{uv}, level(#{lod}))"
          end

          "#{texture}.sample(rlsl_texture_sampler, #{uv})"
        end

        def emit_binary_op(node)
          return emit_named_call("rlsl_mod", [node.left, node.right]) if node.operator == "%" && node.type == :float

          super
        end

        def emit_func_call(node)
          return emit_named_call("rlsl_mod", node.args) if node.name.to_sym == :mod

          super
        end

        def emit_field_access(node)
          return node.field.to_s if node.receiver.type == :uniforms && node.type == :sampler2D

          code = super
          return "(#{code} != 0)" if node.receiver.type == :uniforms && node.type == :bool

          code
        end

        def emit_tuple_value(node)
          elements = node.elements.map { |element| emit(element) }.join(", ")
          "#{current_return_struct_name}{#{elements}}"
        end
      end
    end
  end
end
