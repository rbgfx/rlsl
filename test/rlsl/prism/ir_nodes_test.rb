# frozen_string_literal: true

require_relative "../../test_helper"

class PrismIRNodeAcceptTest < Test::Unit::TestCase
  class MockVisitor
    attr_reader :visited

    def initialize
      @visited = []
    end

    def method_missing(name, *args)
      @visited << name
      nil
    end

    def respond_to_missing?(*)
      true
    end
  end

  test "Block#accept calls visit_block" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Block.new([])
    node.accept(visitor)
    assert_equal [:visit_block], visitor.visited
  end

  test "VarDecl#accept calls visit_var_decl" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::VarDecl.new(:x, nil)
    node.accept(visitor)
    assert_equal [:visit_var_decl], visitor.visited
  end

  test "VarRef#accept calls visit_var_ref" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::VarRef.new(:x)
    node.accept(visitor)
    assert_equal [:visit_var_ref], visitor.visited
  end

  test "Literal#accept calls visit_literal" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Literal.new(1.0)
    node.accept(visitor)
    assert_equal [:visit_literal], visitor.visited
  end

  test "BoolLiteral#accept calls visit_bool_literal" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::BoolLiteral.new(true)
    node.accept(visitor)
    assert_equal [:visit_bool_literal], visitor.visited
  end

  test "BinaryOp#accept calls visit_binary_op" do
    visitor = MockVisitor.new
    left = RLSL::Prism::IR::Literal.new(1.0)
    right = RLSL::Prism::IR::Literal.new(2.0)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    node.accept(visitor)
    assert_equal [:visit_binary_op], visitor.visited
  end

  test "UnaryOp#accept calls visit_unary_op" do
    visitor = MockVisitor.new
    operand = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::UnaryOp.new("-", operand)
    node.accept(visitor)
    assert_equal [:visit_unary_op], visitor.visited
  end

  test "FuncCall#accept calls visit_func_call" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::FuncCall.new(:sin, [])
    node.accept(visitor)
    assert_equal [:visit_func_call], visitor.visited
  end

  test "FieldAccess#accept calls visit_field_access" do
    visitor = MockVisitor.new
    receiver = RLSL::Prism::IR::VarRef.new(:v)
    node = RLSL::Prism::IR::FieldAccess.new(receiver, "x")
    node.accept(visitor)
    assert_equal [:visit_field_access], visitor.visited
  end

  test "Swizzle#accept calls visit_swizzle" do
    visitor = MockVisitor.new
    receiver = RLSL::Prism::IR::VarRef.new(:v)
    node = RLSL::Prism::IR::Swizzle.new(receiver, "xy")
    node.accept(visitor)
    assert_equal [:visit_swizzle], visitor.visited
  end

  test "IfStatement#accept calls visit_if_statement" do
    visitor = MockVisitor.new
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::IfStatement.new(condition, then_branch)
    node.accept(visitor)
    assert_equal [:visit_if_statement], visitor.visited
  end

  test "Return#accept calls visit_return" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Return.new(nil)
    node.accept(visitor)
    assert_equal [:visit_return], visitor.visited
  end

  test "Assignment#accept calls visit_assignment" do
    visitor = MockVisitor.new
    target = RLSL::Prism::IR::VarRef.new(:x)
    value = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::Assignment.new(target, value)
    node.accept(visitor)
    assert_equal [:visit_assignment], visitor.visited
  end

  test "ForLoop#accept calls visit_for_loop" do
    visitor = MockVisitor.new
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::ForLoop.new(:i,
      RLSL::Prism::IR::Literal.new(0),
      RLSL::Prism::IR::Literal.new(10),
      body)
    node.accept(visitor)
    assert_equal [:visit_for_loop], visitor.visited
  end

  test "WhileLoop#accept calls visit_while_loop" do
    visitor = MockVisitor.new
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::WhileLoop.new(condition, body)
    node.accept(visitor)
    assert_equal [:visit_while_loop], visitor.visited
  end

  test "Break#accept calls visit_break" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Break.new
    node.accept(visitor)
    assert_equal [:visit_break], visitor.visited
  end

  test "Constant#accept calls visit_constant" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Constant.new(:PI)
    node.accept(visitor)
    assert_equal [:visit_constant], visitor.visited
  end

  test "Parenthesized#accept calls visit_parenthesized" do
    visitor = MockVisitor.new
    expr = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::Parenthesized.new(expr)
    node.accept(visitor)
    assert_equal [:visit_parenthesized], visitor.visited
  end

  test "ArrayLiteral#accept calls visit_array_literal" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::ArrayLiteral.new([])
    node.accept(visitor)
    assert_equal [:visit_array_literal], visitor.visited
  end

  test "ArrayIndex#accept calls visit_array_index" do
    visitor = MockVisitor.new
    array = RLSL::Prism::IR::VarRef.new(:arr)
    index = RLSL::Prism::IR::Literal.new(0)
    node = RLSL::Prism::IR::ArrayIndex.new(array, index)
    node.accept(visitor)
    assert_equal [:visit_array_index], visitor.visited
  end

  test "GlobalDecl#accept calls visit_global_decl" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::GlobalDecl.new(:MY_CONST, RLSL::Prism::IR::Literal.new(1.0))
    node.accept(visitor)
    assert_equal [:visit_global_decl], visitor.visited
  end

  test "FunctionDefinition#accept calls visit_function_definition" do
    visitor = MockVisitor.new
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::FunctionDefinition.new(:my_func, [], body)
    node.accept(visitor)
    assert_equal [:visit_function_definition], visitor.visited
  end

  test "MultipleAssignment#accept calls visit_multiple_assignment" do
    visitor = MockVisitor.new
    targets = [RLSL::Prism::IR::VarRef.new(:x), RLSL::Prism::IR::VarRef.new(:y)]
    value = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::MultipleAssignment.new(targets, value)
    node.accept(visitor)
    assert_equal [:visit_multiple_assignment], visitor.visited
  end
end
