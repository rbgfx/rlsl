# frozen_string_literal: true

module RLSL
  module MSL
    class Translator < BaseTranslator
      PROFILE = BaseTranslator.build_profile(
        uniform_target: :msl,
        identifier_replacements: {
          "vec2" => "float2",
          "vec3" => "float3",
          "vec4" => "float4"
        },
        call_rewrites: BaseTranslator.common_call_rewrites(
          target_vec2: "float2",
          target_vec3: "float3",
          target_vec4: "float4"
        )
      )

      protected

      def generate_shader(helpers, fragment)
        <<~MSL
          #include <metal_stdlib>
          using namespace metal;
          #{generated_by_comment("MSL")}

          constexpr sampler rlsl_texture_sampler(coord::normalized, address::clamp_to_edge, filter::linear);

          float rlsl_mod(float x, float y) {
              return x - y * floor(x / y);
          }

          // Uniform buffer structure
          struct Uniforms {
              #{generate_uniform_struct}
          };

          // Helper functions
          #{helpers}

          // Fragment shader function
          float3 shader_fragment(float2 frag_coord, float2 resolution, constant Uniforms& u#{fragment_texture_parameters}) {
          #{indent_source(fragment, 4)}
          }

          // Compute kernel entry point
          kernel void compute_shader(
              texture2d<float, access::write> output [[texture(0)]],
              constant Uniforms& u [[buffer(0)]],
          #{kernel_texture_parameters}
              uint2 gid [[thread_position_in_grid]]
          ) {
              float2 resolution = float2(output.get_width(), output.get_height());
              if (gid.x >= uint(resolution.x) || gid.y >= uint(resolution.y)) return;

              float2 frag_coord = float2(gid.x, resolution.y - 1.0 - float(gid.y));
              float3 color = shader_fragment(frag_coord, resolution, u#{fragment_texture_arguments});

              output.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
          }
        MSL
      end

      private

      def profile
        PROFILE
      end

      def generate_uniform_struct
        fields = uniform_lines(resolution_line: "#{target_vec2_type} resolution;") do |name, msl_type|
          "#{msl_type} #{name};"
        end
        fields.join("\n    ")
      end

      def fragment_texture_parameters
        texture_uniforms.keys.map { |name| ", texture2d<float> #{name}" }.join
      end

      def fragment_texture_arguments
        texture_uniforms.keys.map { |name| ", #{name}" }.join
      end

      def kernel_texture_parameters
        texture_uniforms.keys.each_with_index.map do |name, index|
          "    texture2d<float, access::sample> #{name} [[texture(#{index + 1})]],"
        end.join("\n")
      end
    end
  end
end
