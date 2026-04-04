# frozen_string_literal: true

require_relative "../test_helper"

class WGSLTranslatorTest < Test::Unit::TestCase
  test "translate removes static keyword" do
    translator = RLSL::WGSL::Translator.new({}, "static float x = 1.0;", "")
    result = translator.translate

    assert_false result.include?("static f32")
  end

  test "translate removes inline keyword" do
    translator = RLSL::WGSL::Translator.new({}, "inline float helper() { return 1.0; }", "")
    result = translator.translate

    assert_false result.include?("inline f32")
  end

  test "translate replaces float with f32" do
    translator = RLSL::WGSL::Translator.new({}, "float x = 1.0;", "float y = 2.0;")
    result = translator.translate

    assert result.include?("f32 x = 1.0;")
    assert result.include?("f32 y = 2.0;")
  end

  test "generates uniform struct with resolution" do
    translator = RLSL::WGSL::Translator.new({ time: :float }, "", "")
    result = translator.translate

    assert result.include?("resolution: vec2<f32>,")
    assert result.include?("time: f32,")
  end

  test "generates compute shader with workgroup" do
    translator = RLSL::WGSL::Translator.new({}, "", "return vec3<f32>(1.0);")
    result = translator.translate

    assert result.include?("@compute @workgroup_size(8, 8)")
    assert result.include?("fn main")
  end

  test "target_float_type returns f32" do
    translator = RLSL::WGSL::Translator.new({}, "", "")
    assert_equal "f32", translator.send(:target_float_type)
  end

  test "target types are WGSL types" do
    translator = RLSL::WGSL::Translator.new({}, "", "")

    assert_equal "vec2<f32>", translator.send(:target_vec2_type)
    assert_equal "vec3<f32>", translator.send(:target_vec3_type)
    assert_equal "vec4<f32>", translator.send(:target_vec4_type)
  end
end
