# frozen_string_literal: true

require_relative "../../test_helper"

class EmitterProfileTest < Test::Unit::TestCase
  test "GLSL emitter profile includes matrix types" do
    type_map = RLSL::Prism::Emitters::GLSLEmitter::PROFILE.type_map
    assert_equal "mat2", type_map[:mat2]
    assert_equal "mat3", type_map[:mat3]
    assert_equal "mat4", type_map[:mat4]
    assert_equal "sampler2D", type_map[:sampler2D]
  end

  test "WGSL emitter profile includes matrix types" do
    type_map = RLSL::Prism::Emitters::WGSLEmitter::PROFILE.type_map
    assert_equal "mat2x2<f32>", type_map[:mat2]
    assert_equal "mat3x3<f32>", type_map[:mat3]
    assert_equal "mat4x4<f32>", type_map[:mat4]
    assert_equal "texture_2d<f32>", type_map[:sampler2D]
  end

  test "MSL emitter profile includes matrix types" do
    type_map = RLSL::Prism::Emitters::MSLEmitter::PROFILE.type_map
    assert_equal "float2x2", type_map[:mat2]
    assert_equal "float3x3", type_map[:mat3]
    assert_equal "float4x4", type_map[:mat4]
    assert_equal "texture2d<float>", type_map[:sampler2D]
  end

  test "C emitter profile includes matrix types" do
    type_map = RLSL::Prism::Emitters::CEmitter::PROFILE.type_map
    assert_equal "mat2", type_map[:mat2]
    assert_equal "mat3", type_map[:mat3]
    assert_equal "mat4", type_map[:mat4]
    assert_equal "sampler2D", type_map[:sampler2D]
  end

  test "GLSL emitter profile exposes matrix constructors" do
    constructors = RLSL::Prism::Emitters::GLSLEmitter::PROFILE.matrix_constructors
    assert_equal "mat2", constructors[:mat2]
    assert_equal "mat3", constructors[:mat3]
    assert_equal "mat4", constructors[:mat4]
  end

  test "WGSL emitter profile exposes matrix constructors" do
    constructors = RLSL::Prism::Emitters::WGSLEmitter::PROFILE.matrix_constructors
    assert_equal "mat2x2<f32>", constructors[:mat2]
    assert_equal "mat3x3<f32>", constructors[:mat3]
    assert_equal "mat4x4<f32>", constructors[:mat4]
  end

  test "MSL emitter profile exposes matrix constructors" do
    constructors = RLSL::Prism::Emitters::MSLEmitter::PROFILE.matrix_constructors
    assert_equal "float2x2", constructors[:mat2]
    assert_equal "float3x3", constructors[:mat3]
    assert_equal "float4x4", constructors[:mat4]
  end

  test "C emitter profile exposes matrix constructors" do
    constructors = RLSL::Prism::Emitters::CEmitter::PROFILE.matrix_constructors
    assert_equal "mat2_new", constructors[:mat2]
    assert_equal "mat3_new", constructors[:mat3]
    assert_equal "mat4_new", constructors[:mat4]
  end

  test "GLSL emitter profile exposes texture functions" do
    funcs = RLSL::Prism::Emitters::GLSLEmitter::PROFILE.texture_functions
    assert_equal "texture2D", funcs[:texture2D]
    assert_equal "texture", funcs[:texture]
    assert_equal "textureLod", funcs[:textureLod]
  end

  test "WGSL emitter profile exposes texture functions" do
    funcs = RLSL::Prism::Emitters::WGSLEmitter::PROFILE.texture_functions
    assert_equal "textureSample", funcs[:texture2D]
    assert_equal "textureSample", funcs[:texture]
    assert_equal "textureSampleLevel", funcs[:textureLod]
  end

  test "MSL emitter profile exposes texture functions" do
    funcs = RLSL::Prism::Emitters::MSLEmitter::PROFILE.texture_functions
    assert_equal "sample", funcs[:texture2D]
    assert_equal "sample", funcs[:texture]
    assert_equal "sample", funcs[:textureLod]
  end

  test "C emitter profile exposes texture functions" do
    funcs = RLSL::Prism::Emitters::CEmitter::PROFILE.texture_functions
    assert_equal "texture_sample", funcs[:texture2D]
    assert_equal "texture_sample", funcs[:texture]
    assert_equal "texture_sample_lod", funcs[:textureLod]
  end

  test "C emitter profile exposes call and binary resolvers" do
    profile = RLSL::Prism::Emitters::CEmitter::PROFILE

    assert_equal :emit_profile_func_call, profile.call_resolver
    assert_equal :emit_profile_binary_op, profile.binary_op_resolver
  end
end
