# frozen_string_literal: true

require_relative "../test_helper"

class BaseTranslatorTest < Test::Unit::TestCase
  # Create a concrete subclass for testing
  class TestTranslator < RLSL::BaseTranslator
    CALL_REWRITES = {
      "test_func" => RLSL::BaseTranslator.rename_call("replaced_func")
    }.freeze

    TYPE_MAP = {
      "int" => "integer"
    }.freeze

    def generate_shader(helpers, fragment)
      "HELPERS: #{helpers}\nFRAGMENT: #{fragment}"
    end

    def target_vec2_type
      "test_vec2"
    end

    def target_vec3_type
      "test_vec3"
    end

    def target_vec4_type
      "test_vec4"
    end

    def uniform_target
      :wgsl
    end
  end

  def setup
    @translator = TestTranslator.new({ time: :float }, "helper code", "fragment code")
  end

  test "initializes with uniforms, helpers, and fragment code" do
    translator = TestTranslator.new({ time: :float }, "helpers", "fragment")
    assert_not_nil translator
  end

  test "translate applies type map" do
    translator = TestTranslator.new({}, "int x = 1;", "int y = 2;")
    result = translator.translate
    assert result.include?("integer x = 1;")
    assert result.include?("integer y = 2;")
  end

  test "translate applies func replacements" do
    translator = TestTranslator.new({}, "test_func(x)", "test_func(y)")
    result = translator.translate
    assert result.include?("replaced_func(x)")
    assert result.include?("replaced_func(y)")
  end

  test "translate rewrites nested calls without losing balanced arguments" do
    translator = RLSL::WGSL::Translator.new({}, "", "vec3_new(mix_f(a, b, t), sinf(x), cosf(y))")
    result = translator.translate

    assert result.include?("vec3<f32>(mix(a, b, t), sin(x), cos(y))")
  end

  test "translate leaves comments and strings unchanged" do
    translator = TestTranslator.new(
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
    translator = TestTranslator.new({}, "/* int should stay test_func(a) */", "int y = 2;")
    result = translator.translate

    assert_include result, "/* int should stay test_func(a) */"
    assert_include result, "integer y = 2;"
  end

  test "translate handles nil helpers code" do
    translator = TestTranslator.new({}, nil, "fragment")
    result = translator.translate
    assert result.include?("HELPERS:")
    assert result.include?("FRAGMENT: fragment")
  end

  test "translate handles nil fragment code" do
    translator = TestTranslator.new({}, "helpers", nil)
    result = translator.translate
    assert result.include?("HELPERS: helpers")
    assert result.include?("FRAGMENT:")
  end

  test "translate handles empty strings" do
    translator = TestTranslator.new({}, "", "")
    result = translator.translate
    assert_kind_of String, result
  end

  test "uniform_type_to_target returns float for float" do
    assert_equal "float", @translator.send(:uniform_type_to_target, :float)
  end

  test "uniform_type_to_target returns vec2 for vec2" do
    assert_equal "test_vec2", @translator.send(:uniform_type_to_target, :vec2)
  end

  test "uniform_type_to_target returns vec3 for vec3" do
    assert_equal "test_vec3", @translator.send(:uniform_type_to_target, :vec3)
  end

  test "uniform_type_to_target returns vec4 for vec4" do
    assert_equal "test_vec4", @translator.send(:uniform_type_to_target, :vec4)
  end

  test "uniform_type_to_target returns i32 for int" do
    assert_equal "i32", @translator.send(:uniform_type_to_target, :int)
  end

  test "uniform_type_to_target returns bool for bool" do
    assert_equal "bool", @translator.send(:uniform_type_to_target, :bool)
  end

  test "target_float_type returns float" do
    assert_equal "float", @translator.send(:target_float_type)
  end
end

class BaseTranslatorCommonRewritesTest < Test::Unit::TestCase
  test "common_call_rewrites generates vector constructor replacements" do
    rewrites = RLSL::BaseTranslator.common_call_rewrites(
      target_vec2: "float2",
      target_vec3: "float3",
      target_vec4: "float4"
    )

    assert_equal "float2(1.0, 2.0)", rewrites.fetch("vec2_new").call(["1.0", "2.0"])
    assert_equal "float3(1.0, 2.0, 3.0)", rewrites.fetch("vec3_new").call(["1.0", "2.0", "3.0"])
    assert_equal "float4(1.0, 2.0, 3.0, 4.0)", rewrites.fetch("vec4_new").call(["1.0", "2.0", "3.0", "4.0"])
  end

  test "common_call_rewrites includes math function replacements" do
    rewrites = RLSL::BaseTranslator.common_call_rewrites(
      target_vec2: "vec2",
      target_vec3: "vec3",
      target_vec4: "vec4"
    )

    assert_equal "sqrt(x)", rewrites.fetch("sqrtf").call(["x"])
    assert_equal "sin(y)", rewrites.fetch("sinf").call(["y"])
    assert_equal "cos(z)", rewrites.fetch("cosf").call(["z"])
  end

  test "common_call_rewrites includes vector operation replacements" do
    rewrites = RLSL::BaseTranslator.common_call_rewrites(
      target_vec2: "vec2",
      target_vec3: "vec3",
      target_vec4: "vec4"
    )

    assert_equal "(a + b)", rewrites.fetch("vec2_add").call(%w[a b])
    assert_equal "(a - b)", rewrites.fetch("vec3_sub").call(%w[a b])
    assert_equal "dot(a, b)", rewrites.fetch("vec2_dot").call(%w[a b])
    assert_equal "normalize(v)", rewrites.fetch("vec3_normalize").call(["v"])
  end
end

class BaseTranslatorNotImplementedTest < Test::Unit::TestCase
  # Test that base class raises NotImplementedError for abstract methods
  class IncompleteTranslator < RLSL::BaseTranslator
    # Don't override generate_shader or target methods
  end

  test "generate_shader raises NotImplementedError" do
    translator = IncompleteTranslator.new({}, "", "")
    assert_raise(NotImplementedError) do
      translator.translate
    end
  end

  test "target_vec2_type raises NotImplementedError" do
    translator = IncompleteTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec2_type)
    end
  end

  test "target_vec3_type raises NotImplementedError" do
    translator = IncompleteTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec3_type)
    end
  end

  test "target_vec4_type raises NotImplementedError" do
    translator = IncompleteTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec4_type)
    end
  end
end
