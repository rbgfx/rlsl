# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/base_translator_test_case"

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
