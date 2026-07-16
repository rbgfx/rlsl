# frozen_string_literal: true

require_relative "../test_helper"

class MSLTranslatorTest < Test::Unit::TestCase
  test "translate removes static keyword" do
    translator = RLSL::MSL::Translator.new({}, "static float x = 1.0;", "")
    result = translator.translate

    assert_false result.include?("static float")
  end

  test "translate removes inline keyword" do
    translator = RLSL::MSL::Translator.new({}, "inline float helper() { return 1.0; }", "")
    result = translator.translate

    assert_false result.include?("inline float")
  end

  test "generates uniform struct with resolution" do
    translator = RLSL::MSL::Translator.new({ time: :float }, "", "")
    result = translator.translate

    assert result.include?("float2 resolution;")
    assert result.include?("float time;")
  end

  test "generates compute kernel" do
    translator = RLSL::MSL::Translator.new({}, "", "return float3(1.0);")
    result = translator.translate

    assert result.include?("kernel void compute_shader")
    assert result.include?("texture2d<float, access::write> output")
  end

  test "target types are Metal types" do
    translator = RLSL::MSL::Translator.new({}, "", "")

    assert_equal "float2", translator.send(:target_vec2_type)
    assert_equal "float3", translator.send(:target_vec3_type)
    assert_equal "float4", translator.send(:target_vec4_type)
  end

  test "translates C to MSL with headers" do
    uniforms = { time: :float }
    helpers = "static inline float helper(float x) { return x * 2.0f; }"
    fragment = "return vec3_new(1.0f, 0.0f, 0.0f);"

    translator = RLSL::MSL::Translator.new(uniforms, helpers, fragment)
    msl = translator.translate

    assert msl.include?("#include <metal_stdlib>")
    assert msl.include?("using namespace metal;")
    assert msl.include?("struct Uniforms")
    assert msl.include?("float time;")
    assert msl.include?("kernel void compute_shader")
  end

  test "replaces vec2_new with float2" do
    translator = RLSL::MSL::Translator.new({}, "", "vec2_new(1.0f, 2.0f)")
    msl = translator.translate
    assert msl.include?("float2(1.0f, 2.0f)")
  end

  test "replaces vec3_new with float3" do
    translator = RLSL::MSL::Translator.new({}, "", "vec3_new(1.0f, 2.0f, 3.0f)")
    msl = translator.translate
    assert msl.include?("float3(1.0f, 2.0f, 3.0f)")
  end

  test "replaces math functions" do
    translator = RLSL::MSL::Translator.new({}, "", "sqrtf(x) sinf(y) cosf(z)")
    msl = translator.translate
    assert msl.include?("sqrt(x)")
    assert msl.include?("sin(y)")
    assert msl.include?("cos(z)")
  end

  test "handles empty code" do
    translator = RLSL::MSL::Translator.new({}, nil, nil)
    msl = translator.translate
    assert msl.include?("kernel void compute_shader")
  end

  test "generates proper uniform types" do
    uniforms = { time: :float, frame: :int, enabled: :bool, mouse: :vec2, pos: :vec3, color: :vec4 }
    translator = RLSL::MSL::Translator.new(uniforms, "", "")
    msl = translator.translate

    assert msl.include?("float time;")
    assert msl.include?("int frame;")
    assert msl.include?("int enabled;")
    assert msl.include?("float2 mouse;")
    assert msl.include?("float3 pos;")
    assert msl.include?("float4 color;")
  end
end
