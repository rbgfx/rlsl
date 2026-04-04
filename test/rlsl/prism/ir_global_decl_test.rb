# frozen_string_literal: true

require_relative "../../test_helper"

class PrismIRGlobalDeclTest < Test::Unit::TestCase
  test "GlobalDecl stores all properties" do
    init = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::GlobalDecl.new(
      :MY_CONST,
      init,
      type: :float,
      is_const: true,
      is_static: true,
      array_size: nil,
      element_type: nil
    )

    assert_equal :MY_CONST, node.name
    assert_equal init, node.initializer
    assert_equal :float, node.type
    assert_true node.is_const
    assert_true node.is_static
  end

  test "GlobalDecl supports array configuration" do
    elements = [
      RLSL::Prism::IR::Literal.new(1.0),
      RLSL::Prism::IR::Literal.new(2.0)
    ]
    init = RLSL::Prism::IR::ArrayLiteral.new(elements)
    node = RLSL::Prism::IR::GlobalDecl.new(
      :MY_ARRAY,
      init,
      array_size: 2,
      element_type: :float
    )

    assert_equal 2, node.array_size
    assert_equal :float, node.element_type
  end
end
