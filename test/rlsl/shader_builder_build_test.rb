# frozen_string_literal: true

require_relative "../test_helper"

class ShaderBuilderBuildMethodsRubyModeTest < Test::Unit::TestCase
  test "build_metal_shader in ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_metal)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    shader = builder.build_metal_shader
    assert_kind_of RLSL::MSL::Shader, shader
    assert shader.msl_source.include?("float3")
  end

  test "build_wgsl_shader in ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_wgsl)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    wgsl = builder.build_wgsl_shader
    assert wgsl.include?("vec3<f32>")
  end

  test "build_glsl_shader in ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_glsl)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    glsl = builder.build_glsl_shader
    assert glsl.include?("vec3")
  end

  test "build_metal_shader transpiles ruby helpers" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_helper_metal)
    builder.functions do
      vec3 :helper_color
    end
    builder.helpers(:ruby) do
      def helper_color
        vec3(1.0, 0.0, 0.0)
      end
    end
    builder.fragment { |frag_coord, resolution, u| helper_color }

    shader = builder.build_metal_shader

    assert_kind_of RLSL::MSL::Shader, shader
    assert shader.msl_source.include?("float3 helper_color()")
  end

  test "build_wgsl_shader transpiles ruby helpers" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_helper_wgsl)
    builder.functions do
      vec3 :helper_color
    end
    builder.helpers(:ruby) do
      def helper_color
        vec3(1.0, 0.0, 0.0)
      end
    end
    builder.fragment { |frag_coord, resolution, u| helper_color }

    wgsl = builder.build_wgsl_shader

    assert wgsl.include?("fn helper_color() -> vec3<f32>")
  end

  test "build_glsl_shader transpiles ruby helpers" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_helper_glsl)
    builder.functions do
      vec3 :helper_color
    end
    builder.helpers(:ruby) do
      def helper_color
        vec3(1.0, 0.0, 0.0)
      end
    end
    builder.fragment { |frag_coord, resolution, u| helper_color }

    glsl = builder.build_glsl_shader

    assert glsl.include?("vec3 helper_color()")
  end

  test "build_metal_shader with helpers" do
    builder = RLSL::ShaderBuilder.new(:test_with_helpers)
    builder.uniforms { float :time }
    builder.helpers(:c) { "// custom helper" }
    builder.fragment { "return vec3_new(1.0f, 0.0f, 0.0f);" }

    shader = builder.build_metal_shader
    assert_kind_of RLSL::MSL::Shader, shader
  end

  test "build_wgsl_shader rejects C helpers" do
    builder = RLSL::ShaderBuilder.new(:test_wgsl_helpers)
    builder.uniforms { float :time }
    builder.helpers(:c) { "// custom helper" }
    builder.fragment { "return vec3_new(1.0f, 0.0f, 0.0f);" }

    assert_raise(RLSL::TranslationError) { builder.build_wgsl_shader }
  end

  test "build_glsl_shader with helpers" do
    builder = RLSL::ShaderBuilder.new(:test_glsl_helpers)
    builder.uniforms { float :time }
    builder.helpers(:c) { "// custom helper" }
    builder.fragment { "return vec3_new(1.0f, 0.0f, 0.0f);" }

    glsl = builder.build_glsl_shader
    assert_kind_of String, glsl
  end
end
