# frozen_string_literal: true

module RLSL
  module WGSL
    class Translator < BaseTranslator
      PROFILE = BaseTranslator.build_profile(
        uniform_target: :wgsl,
        identifier_replacements: {
          "float" => "f32",
          "int" => "i32",
          "vec2" => "vec2<f32>",
          "vec3" => "vec3<f32>",
          "vec4" => "vec4<f32>"
        },
        call_rewrites: BaseTranslator.common_call_rewrites(
          target_vec2: "vec2<f32>",
          target_vec3: "vec3<f32>",
          target_vec4: "vec4<f32>"
        ).merge("fmodf" => BaseTranslator.infix_call("%"))
      )

      protected

      def validate_source_format!(source)
        return if source.target_code?

        raise RLSL::TranslationError,
              "WGSL generation only supports Ruby shader source; legacy C source cannot be translated to WGSL"
      end

      def generate_shader(helpers, fragment)
        <<~WGSL
          #{generated_by_comment("WGSL")}

          struct Uniforms {
              #{generate_uniform_struct}
          }

          @group(0) @binding(0) var<uniform> u: Uniforms;
          @group(0) @binding(1) var output_texture: texture_storage_2d<rgba8unorm, write>;
          #{generate_texture_declarations}

          #{helpers}

          fn shader_fragment(frag_coord: vec2<f32>, resolution: vec2<f32>) -> vec3<f32> {
          #{indent_source(fragment, 4)}
          }

          @compute @workgroup_size(8, 8)
          fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
              let resolution = vec2<f32>(f32(textureDimensions(output_texture).x),
                                         f32(textureDimensions(output_texture).y));
              if (gid.x >= u32(resolution.x) || gid.y >= u32(resolution.y)) {
                  return;
              }

              let frag_coord = vec2<f32>(f32(gid.x), resolution.y - 1.0 - f32(gid.y));
              let color = shader_fragment(frag_coord, resolution);

              textureStore(output_texture, vec2<i32>(i32(gid.x), i32(gid.y)),
                           vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0));
          }
        WGSL
      end

      private

      def profile
        PROFILE
      end

      def target_float_type
        UniformTypes.target_type(:float, uniform_target)
      end

      def generate_uniform_struct
        fields = uniform_lines(resolution_line: "resolution: #{target_vec2_type},") do |name, wgsl_type|
          "#{name}: #{wgsl_type},"
        end
        fields.join("\n    ")
      end

      def generate_texture_declarations
        texture_uniforms.each_with_index.flat_map do |(name, _type), index|
          binding = 2 + index * 2
          [
            "@group(0) @binding(#{binding}) var #{name}: texture_2d<f32>;",
            "@group(0) @binding(#{binding + 1}) var #{name}_sampler: sampler;"
          ]
        end.join("\n")
      end
    end
  end
end
