# frozen_string_literal: true

require_relative "../../test_helper"

class PrismTranspilerApplySignaturesTest < Test::Unit::TestCase
  test "apply_function_signatures does nothing for non-block" do
    transpiler = RLSL::Prism::Transpiler.new

    transpiler.send(:apply_function_signatures, nil, {})
    transpiler.send(:apply_function_signatures, RLSL::Prism::IR::Literal.new(1.0), {})
  end

  test "apply_function_signatures updates function definitions" do
    transpiler = RLSL::Prism::Transpiler.new

    func_def = RLSL::Prism::IR::FunctionDefinition.new(
      :my_func,
      [:x],
      RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::VarRef.new(:x))])
    )
    block = RLSL::Prism::IR::Block.new([func_def])

    signatures = { my_func: { returns: :vec3, params: { x: :float } } }
    transpiler.send(:apply_function_signatures, block, signatures)

    assert_equal :vec3, func_def.return_type
    assert_equal({ x: :float }, func_def.param_types)
  end

  test "apply_function_signatures skips unknown functions" do
    transpiler = RLSL::Prism::Transpiler.new

    func_def = RLSL::Prism::IR::FunctionDefinition.new(
      :unknown_func,
      [],
      RLSL::Prism::IR::Block.new([])
    )
    block = RLSL::Prism::IR::Block.new([func_def])

    transpiler.send(:apply_function_signatures, block, { other_func: { returns: :float } })
    assert_nil func_def.return_type
  end
end
