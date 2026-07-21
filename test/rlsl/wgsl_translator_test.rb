# frozen_string_literal: true

require_relative "../test_helper"

class WGSLTranslatorTest < Test::Unit::TestCase
  test "rejects legacy C source" do
    translator = RLSL::WGSL::Translator.new({}, "float helper(void) { return 1.0f; }", "")

    error = assert_raise(RLSL::TranslationError) { translator.translate }
    assert_include error.message, "only supports Ruby shader source"
  end

  test "accepts target WGSL source" do
    translator = RLSL::WGSL::Translator.new({}, target_source("fn helper() -> f32 { return 1.0; }"), "")

    assert_include translator.translate, "fn helper() -> f32"
  end

  test "generates uniform struct with resolution" do
    translator = RLSL::WGSL::Translator.new({ time: :float }, "", "")
    result = translator.translate

    assert result.include?("resolution: vec2<f32>,")
    assert result.include?("time: f32,")
  end

  test "generates compute shader with workgroup" do
    translator = RLSL::WGSL::Translator.new({}, "", target_source("return vec3<f32>(1.0);"))
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

  private

  def target_source(code)
    RLSL::BaseTranslator::SourceSnippet.new(code: code, format: :target)
  end
end
