# frozen_string_literal: true

require_relative "../../test_helper"

class PrismTranspilerHelpersTest < Test::Unit::TestCase
  test "transpile_helpers with function signatures" do
    transpiler = RLSL::Prism::Transpiler.new(
      { time: :float },
      { helper_func: { returns: :float } }
    )

    block = proc do
      x = 1.0
      x
    end

    result = transpiler.transpile_helpers(block, :c, { helper_func: { returns: :float } })
    assert_kind_of String, result
  end

  test "transpile_helpers raises for custom signature mismatch" do
    transpiler = RLSL::Prism::Transpiler.new(
      {},
      { helper_func: { returns: :float, params: { uv: :vec2 } } }
    )

    block = proc do
      helper_func(1.0)
    end

    error = assert_raise(RLSL::Prism::SignatureError) do
      transpiler.transpile_helpers(block, :c, { helper_func: { returns: :float, params: { uv: :vec2 } } })
    end

    assert_include error.message, "expected vec2, got float"
  end
end
