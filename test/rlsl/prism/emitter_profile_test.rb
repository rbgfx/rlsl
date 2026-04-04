# frozen_string_literal: true

require_relative "../../test_helper"

class EmitterTypeMapTest < Test::Unit::TestCase
  test "GLSL emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::GLSLEmitter::TYPE_MAP
    assert_equal "mat2", type_map[:mat2]
    assert_equal "mat3", type_map[:mat3]
    assert_equal "mat4", type_map[:mat4]
    assert_equal "sampler2D", type_map[:sampler2D]
  end

  test "WGSL emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::WGSLEmitter::TYPE_MAP
    assert_equal "mat2x2<f32>", type_map[:mat2]
    assert_equal "mat3x3<f32>", type_map[:mat3]
    assert_equal "mat4x4<f32>", type_map[:mat4]
    assert_equal "texture_2d<f32>", type_map[:sampler2D]
  end

  test "MSL emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::MSLEmitter::TYPE_MAP
    assert_equal "float2x2", type_map[:mat2]
    assert_equal "float3x3", type_map[:mat3]
    assert_equal "float4x4", type_map[:mat4]
    assert_equal "texture2d<float>", type_map[:sampler2D]
  end

  test "C emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::CEmitter::TYPE_MAP
    assert_equal "mat2", type_map[:mat2]
    assert_equal "mat3", type_map[:mat3]
    assert_equal "mat4", type_map[:mat4]
    assert_equal "sampler2D", type_map[:sampler2D]
  end

  test "GLSL emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::GLSLEmitter::MATRIX_CONSTRUCTORS
    assert_equal "mat2", constructors[:mat2]
    assert_equal "mat3", constructors[:mat3]
    assert_equal "mat4", constructors[:mat4]
  end

  test "WGSL emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::WGSLEmitter::MATRIX_CONSTRUCTORS
    assert_equal "mat2x2<f32>", constructors[:mat2]
    assert_equal "mat3x3<f32>", constructors[:mat3]
    assert_equal "mat4x4<f32>", constructors[:mat4]
  end

  test "MSL emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::MSLEmitter::MATRIX_CONSTRUCTORS
    assert_equal "float2x2", constructors[:mat2]
    assert_equal "float3x3", constructors[:mat3]
    assert_equal "float4x4", constructors[:mat4]
  end

  test "C emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::CEmitter::MATRIX_CONSTRUCTORS
    assert_equal "mat2_new", constructors[:mat2]
    assert_equal "mat3_new", constructors[:mat3]
    assert_equal "mat4_new", constructors[:mat4]
  end

  test "GLSL emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::GLSLEmitter::TEXTURE_FUNCTIONS
    assert_equal "texture2D", funcs[:texture2D]
    assert_equal "texture", funcs[:texture]
    assert_equal "textureLod", funcs[:textureLod]
  end

  test "WGSL emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::WGSLEmitter::TEXTURE_FUNCTIONS
    assert_equal "textureSample", funcs[:texture2D]
    assert_equal "textureSample", funcs[:texture]
    assert_equal "textureSampleLevel", funcs[:textureLod]
  end

  test "MSL emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::MSLEmitter::TEXTURE_FUNCTIONS
    assert_equal "sample", funcs[:texture2D]
    assert_equal "sample", funcs[:texture]
    assert_equal "sample", funcs[:textureLod]
  end

  test "C emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::CEmitter::TEXTURE_FUNCTIONS
    assert_equal "texture_sample", funcs[:texture2D]
    assert_equal "texture_sample", funcs[:texture]
    assert_equal "texture_sample_lod", funcs[:textureLod]
  end
end
