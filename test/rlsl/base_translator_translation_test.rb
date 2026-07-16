# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/base_translator_test_case"

class BaseTranslatorTranslationTest < Test::Unit::TestCase
  def setup
    @translator = BaseTranslatorTestTranslator.new({ time: :float }, "helper code", "fragment code")
  end

  test "initializes with uniforms, helpers, and fragment code" do
    translator = BaseTranslatorTestTranslator.new({ time: :float }, "helpers", "fragment")
    assert_not_nil translator
  end

  test "translate applies type map" do
    translator = BaseTranslatorTestTranslator.new({}, "int x = 1;", "int y = 2;")
    result = translator.translate
    assert result.include?("integer x = 1;")
    assert result.include?("integer y = 2;")
  end

  test "translate applies func replacements" do
    translator = BaseTranslatorTestTranslator.new({}, "test_func(x)", "test_func(y)")
    result = translator.translate
    assert result.include?("replaced_func(x)")
    assert result.include?("replaced_func(y)")
  end

  test "translate rewrites nested calls without losing balanced arguments" do
    translator = RLSL::WGSL::Translator.new({}, "", "vec3_new(mix_f(a, b, t), sinf(x), cosf(y))")
    result = translator.translate

    assert result.include?("vec3<f32>(mix(a, b, t), sin(x), cos(y))")
  end

  test "translate leaves Prism-targeted snippets untouched" do
    targeted = RLSL::BaseTranslator::SourceSnippet.new(code: "int x = 1;", format: :target)
    translator = BaseTranslatorTestTranslator.new({}, targeted, targeted)

    result = translator.translate

    assert_include result, "HELPERS: int x = 1;"
    assert_include result, "FRAGMENT: int x = 1;"
  end

  test "translate leaves comments and strings unchanged" do
    translator = BaseTranslatorTestTranslator.new(
      {},
      "// test_func(x)\nconst char* label = \"test_func(y)\";",
      "test_func(z)"
    )

    result = translator.translate

    assert_include result, "// test_func(x)"
    assert_include result, "\"test_func(y)\""
    assert_include result, "replaced_func(z)"
  end

  test "translate leaves block comments unchanged" do
    translator = BaseTranslatorTestTranslator.new({}, "/* int should stay test_func(a) */", "int y = 2;")
    result = translator.translate

    assert_include result, "/* int should stay test_func(a) */"
    assert_include result, "integer y = 2;"
  end

  test "translate handles nil helpers code" do
    translator = BaseTranslatorTestTranslator.new({}, nil, "fragment")
    result = translator.translate
    assert result.include?("HELPERS:")
    assert result.include?("FRAGMENT: fragment")
  end

  test "translate handles nil fragment code" do
    translator = BaseTranslatorTestTranslator.new({}, "helpers", nil)
    result = translator.translate
    assert result.include?("HELPERS: helpers")
    assert result.include?("FRAGMENT:")
  end

  test "translate handles empty strings" do
    translator = BaseTranslatorTestTranslator.new({}, "", "")
    result = translator.translate
    assert_kind_of String, result
  end

  test "uniform_type_to_target resolves supported scalar and vector types" do
    assert_equal "float", @translator.send(:uniform_type_to_target, :float)
    assert_equal "test_vec2", @translator.send(:uniform_type_to_target, :vec2)
    assert_equal "test_vec3", @translator.send(:uniform_type_to_target, :vec3)
    assert_equal "test_vec4", @translator.send(:uniform_type_to_target, :vec4)
    assert_equal "i32", @translator.send(:uniform_type_to_target, :int)
    assert_equal "i32", @translator.send(:uniform_type_to_target, :bool)
  end

  test "target_float_type returns float" do
    assert_equal "float", @translator.send(:target_float_type)
  end
end
