# frozen_string_literal: true

require_relative "../test_helper"

class ReviewRegressionsTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new
  end

  test "block parameters shadow fragment parameter aliases" do
    code = @transpiler.transpile_source(<<~RUBY, :glsl)
      |coord, size, uniforms|
      2.times do |coord|
        value = coord
      end
      vec3(coord.x, size.y, 0.0)
    RUBY

    assert_include code, "int value = coord"
    assert_not_include code, "int value = frag_coord"
  end

  test "uniforms may use the freeze member name" do
    transpiler = RLSL::Prism::Transpiler.new({ freeze: :float })

    assert_include transpiler.transpile_source("vec3(u.freeze)", :glsl), "u.freeze"
  end

  test "multiple assignment canonicalizes fragment aliases" do
    code = @transpiler.transpile_source(<<~RUBY, :glsl)
      |coord, size, uniforms|
      pair = [vec2(1.0), vec2(2.0)]
      coord, other = pair
      vec3(coord.x, other.y, 0.0)
    RUBY

    assert_include code, "frag_coord = pair[0]"
    assert_not_include code, "\ncoord = pair[0]"
  end

  test "WGSL tuple assignment uses WGSL temporary syntax" do
    transpiler = RLSL::Prism::Transpiler.new(
      {},
      { pair: { returns: %i[float float], params: { value: :float } } }
    )
    code = transpiler.transpile_source("a, b = pair(1.0)\nvec3(a, b, 0.0)", :wgsl)

    assert_match(/let (_rlsl_result\d+): pair_result = pair\(1.0\)/, code)
  end

  test "shader fragments cannot return tuple-shaped arrays" do
    assert_raise(RLSL::Prism::ReturnFlowError) do
      @transpiler.transpile_source("[1.0, 2.0]", :c)
    end
  end

  test "tuple return validation checks every element and arity" do
    signatures = { pair: { returns: %i[float vec2], params: {} } }

    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.transpile_helpers_source("def pair\n[1.0]\nend", :c, signatures)
    end
    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.transpile_helpers_source("def pair\n[1.0, vec3(1.0)]\nend", :c, signatures)
    end
  end

  test "C swizzles evaluate call receivers once" do
    transpiler = RLSL::Prism::Transpiler.new({}, { next_vec: { returns: :vec3, params: {} } })
    code = transpiler.transpile_source("next_vec().zyx", :c)

    assert_equal 1, code.scan("next_vec()").length
  end
end
