# frozen_string_literal: true

require_relative "../test_helper"

class GLSLTranslatorTest < Test::Unit::TestCase
  test "initializes with custom version" do
    translator = RLSL::GLSL::Translator.new({}, "", "", version: "430")
    result = translator.translate

    assert result.include?("#version 430")
  end

  test "default version is 450" do
    translator = RLSL::GLSL::Translator.new({}, "", "")
    result = translator.translate

    assert result.include?("#version 450")
  end

  test "translate removes static keyword" do
    translator = RLSL::GLSL::Translator.new({}, "static float x = 1.0;", "")
    result = translator.translate

    assert_false result.include?("static float")
  end

  test "translate removes inline keyword" do
    translator = RLSL::GLSL::Translator.new({}, "inline float helper() { return 1.0; }", "")
    result = translator.translate

    assert_false result.include?("inline float")
  end

  test "generates uniform block with resolution" do
    translator = RLSL::GLSL::Translator.new({ time: :float }, "", "")
    result = translator.translate

    assert result.include?("layout(binding = 1) uniform ShaderUniforms")
    assert result.include?("vec2 resolution;")
    assert result.include?("float time;")
  end

  test "generates compute shader with local size" do
    translator = RLSL::GLSL::Translator.new({}, "", "return vec3(1.0);")
    result = translator.translate

    assert result.include?("layout(local_size_x = 8, local_size_y = 8) in;")
    assert result.include?("void main()")
  end

  test "generates image output" do
    translator = RLSL::GLSL::Translator.new({}, "", "")
    result = translator.translate

    assert result.include?("layout(rgba8, binding = 0) uniform writeonly image2D outputImage")
  end

  test "target types are GLSL types" do
    translator = RLSL::GLSL::Translator.new({}, "", "")

    assert_equal "vec2", translator.send(:target_vec2_type)
    assert_equal "vec3", translator.send(:target_vec3_type)
    assert_equal "vec4", translator.send(:target_vec4_type)
  end
end
