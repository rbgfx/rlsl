# frozen_string_literal: true

require_relative "../../test_helper"

class PrismIRNodeTypeTest < Test::Unit::TestCase
  test "Literal infers float type from float value" do
    node = RLSL::Prism::IR::Literal.new(1.5)
    assert_equal :float, node.type
  end

  test "Literal infers int type from integer value" do
    node = RLSL::Prism::IR::Literal.new(1)
    assert_equal :int, node.type
  end

  test "Literal uses explicit type when provided" do
    node = RLSL::Prism::IR::Literal.new(1, :float)
    assert_equal :float, node.type
  end

  test "Return inherits expression type" do
    expr = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Return.new(expr)
    assert_equal :float, node.type
  end

  test "Return has nil type for empty return" do
    node = RLSL::Prism::IR::Return.new(nil)
    assert_nil node.type
  end

  test "Assignment inherits value type" do
    target = RLSL::Prism::IR::VarRef.new(:x)
    value = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Assignment.new(target, value)
    assert_equal :float, node.type
  end

  test "Parenthesized inherits expression type" do
    expr = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Parenthesized.new(expr)
    assert_equal :float, node.type
  end

  test "ForLoop has nil type" do
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::ForLoop.new(:i,
      RLSL::Prism::IR::Literal.new(0),
      RLSL::Prism::IR::Literal.new(10),
      body)
    assert_nil node.type
  end

  test "WhileLoop has nil type" do
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::WhileLoop.new(condition, body)
    assert_nil node.type
  end

  test "Break has nil type" do
    node = RLSL::Prism::IR::Break.new
    assert_nil node.type
  end

  test "Constant has float type by default" do
    node = RLSL::Prism::IR::Constant.new(:PI)
    assert_equal :float, node.type
  end

  test "FunctionDefinition inherits return_type" do
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::FunctionDefinition.new(:my_func, [], body, return_type: :vec3)
    assert_equal :vec3, node.type
  end
end
