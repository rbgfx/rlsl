# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/prism_type_inference_helpers"

class PrismTypeInferenceCollectionTest < Test::Unit::TestCase
  include PrismTypeInferenceHelpers

  def setup
    @type_inference = build_type_inference
  end

  test "array literals and indexes infer element types" do
    array_literal = RLSL::Prism::IR::ArrayLiteral.new([literal(1.0), literal(2.0)])
    direct_index = RLSL::Prism::IR::ArrayIndex.new(array_literal, literal(0))
    metadata_index = RLSL::Prism::IR::ArrayIndex.new(var(:weights, :buffer), literal(0))

    @type_inference.register(:weights_element_type, :vec3)

    infer(array_literal)
    infer(direct_index)
    infer(metadata_index)

    assert_equal array_type(:float), array_literal.type
    assert_equal :float, direct_index.type
    assert_equal :vec3, metadata_index.type
  end

  test "global declarations register array metadata and scalar types" do
    array_decl = RLSL::Prism::IR::GlobalDecl.new(
      :weights,
      RLSL::Prism::IR::ArrayLiteral.new([literal(1.0), literal(2.0)])
    )
    scalar_decl = RLSL::Prism::IR::GlobalDecl.new(:exposure, literal(0.5))

    infer(array_decl)
    infer(scalar_decl)

    assert_equal array_type(:float), array_decl.type
    assert_equal 2, array_decl.array_size
    assert_equal :float, array_decl.element_type
    assert_equal array_type(:float), @type_inference.lookup(:weights)
    assert_equal :float, @type_inference.lookup(:weights_element_type)
    assert_equal :float, scalar_decl.type
    assert_equal :float, @type_inference.lookup(:exposure)
  end

  test "multiple assignment supports tuple, array, and custom multi-return values" do
    tuple_assignment = RLSL::Prism::IR::MultipleAssignment.new(
      [var(:x), var(:uv)],
      var(:pair, RLSL::Prism::IR::TupleType.new(:float, :vec2))
    )
    array_assignment = RLSL::Prism::IR::MultipleAssignment.new(
      [var(:left), var(:right)],
      RLSL::Prism::IR::ArrayLiteral.new([literal(1.0), literal(2.0)])
    )
    custom_assignment = RLSL::Prism::IR::MultipleAssignment.new(
      [var(:depth), var(:coords)],
      RLSL::Prism::IR::FuncCall.new(:split_uv, [var(:uv, :vec2)])
    )

    infer(tuple_assignment)
    infer(array_assignment)
    infer(custom_assignment)

    assert_equal :float, tuple_assignment.targets[0].type
    assert_equal :vec2, tuple_assignment.targets[1].type
    assert_equal :float, array_assignment.targets[0].type
    assert_equal :float, array_assignment.targets[1].type
    assert_equal :float, custom_assignment.targets[0].type
    assert_equal :vec2, custom_assignment.targets[1].type
    assert_equal :vec2, @type_inference.lookup(:coords)
  end

  test "empty array literals default to float element types" do
    array_literal = RLSL::Prism::IR::ArrayLiteral.new([])

    infer(array_literal)

    assert_equal array_type(:float), array_literal.type
  end
end
