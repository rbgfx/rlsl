# frozen_string_literal: true

require_relative "../../test_helper"

class PrismASTVisitorEdgeCasesTest < Test::Unit::TestCase
  test "parse for loop without explicit variable" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      for j in 0..5
        x = j
      end
      return x
    RUBY
    ir = visitor.parse(source)
    for_loop = ir.statements.first
    assert_kind_of RLSL::Prism::IR::ForLoop, for_loop
    assert_equal :j, for_loop.variable
  end

  test "parse field access that is not a component" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      v = vec3(1.0, 2.0, 3.0)
      x = v.custom_field
      return x
    RUBY
    ir = visitor.parse(source)
    stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::FieldAccess, stmt.initializer
    assert_equal "custom_field", stmt.initializer.field
  end

  test "parse constant that is not PI or TAU" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      x = CUSTOM_CONST
      return x
    RUBY
    ir = visitor.parse(source)
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::VarRef, stmt.initializer
  end

  test "parse builtin function normalize" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      v = vec3(1.0, 2.0, 3.0)
      x = normalize(v)
      return x
    RUBY
    ir = visitor.parse(source)
    stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :normalize, stmt.initializer.name
  end

  test "parse unless with else" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      x = 1.0
      unless x > 0
        y = 0.0
      else
        y = 1.0
      end
      return y
    RUBY
    ir = visitor.parse(source)
    if_stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::IfStatement, if_stmt
    assert_kind_of RLSL::Prism::IR::UnaryOp, if_stmt.condition
  end
end
