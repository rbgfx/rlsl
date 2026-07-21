# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/prism_type_inference_helpers"

class PrismTypeInferenceScopeTest < Test::Unit::TestCase
  include PrismTypeInferenceHelpers

  def setup
    @type_inference = build_type_inference
  end

  test "block propagates inferred types and updates the symbol table" do
    block = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::VarDecl.new(:energy, literal(1.0)),
      RLSL::Prism::IR::Return.new(var(:energy))
    ])

    infer(block)

    assert_equal :float, block.type
    assert_equal :float, block.statements.first.type
    assert_equal :float, block.statements.last.type
    assert_equal :float, @type_inference.lookup(:energy)
  end

  test "loops keep nil type and keep loop variables scoped" do
    for_loop = RLSL::Prism::IR::ForLoop.new(
      :i,
      literal(0),
      literal(4),
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::Assignment.new(var(:sum), literal(1.0))
      ])
    )
    while_loop = RLSL::Prism::IR::WhileLoop.new(
      RLSL::Prism::IR::BoolLiteral.new(true),
      RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Break.new])
    )

    infer(for_loop)
    infer(while_loop)

    assert_nil for_loop.type
    assert_nil while_loop.type
    assert_nil @type_inference.lookup(:i)
  end

  test "loops require integer bounds" do
    for_loop = RLSL::Prism::IR::ForLoop.new(
      :i,
      literal(0),
      literal(4.5),
      RLSL::Prism::IR::Block.new
    )

    error = assert_raise(RLSL::Prism::SignatureError) { infer(for_loop) }
    assert_include error.message, "Loop bounds must be integers"
  end

  test "function definitions infer return types and keep params scoped to the body" do
    definition = RLSL::Prism::IR::FunctionDefinition.new(
      :distance_from_origin,
      [:x, :y],
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::Return.new(
          RLSL::Prism::IR::BinaryOp.new("+", var(:x), var(:y))
        )
      ]),
      param_types: { x: :float, y: :float }
    )

    infer(definition)

    assert_equal :float, definition.return_type
    assert_equal :float, definition.type
    assert_nil @type_inference.lookup(:x)
    assert_nil @type_inference.lookup(:y)
  end

  test "branch-local declarations do not leak outside conditionals" do
    conditional = RLSL::Prism::IR::IfStatement.new(
      RLSL::Prism::IR::BoolLiteral.new(true),
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::VarDecl.new(:branch_value, literal(1.0))
      ])
    )

    infer(conditional)

    assert_nil @type_inference.lookup(:branch_value)
  end
end
