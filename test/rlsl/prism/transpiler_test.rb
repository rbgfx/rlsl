# frozen_string_literal: true

require_relative "../../test_helper"

class PrismTranspilerTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new({ time: :float })
  end

  test "parse simple variable declaration" do
    source = "x = 1.0\nreturn x"
    ir = @transpiler.parse_source(source)

    assert_kind_of RLSL::Prism::IR::Block, ir
    assert_equal 2, ir.statements.length
    assert_kind_of RLSL::Prism::IR::VarDecl, ir.statements.first
  end

  test "parse binary operation" do
    source = "x = 1.0 + 2.0\nreturn x"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::VarDecl, stmt
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
    assert_equal "+", stmt.initializer.operator
  end

  test "parse function call" do
    source = "x = sin(0.5)\nreturn x"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :sin, stmt.initializer.name
  end

  test "compile_source returns a stateless compilation unit" do
    compilation = @transpiler.compile_source("x = 1.0\nreturn x")

    assert_kind_of RLSL::Prism::CompilationUnit, compilation
    assert_kind_of RLSL::Prism::SourceUnit, compilation.source_unit
    assert_kind_of RLSL::Prism::IR::Block, compilation.ir
  end

  test "parse vec3 constructor" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :vec3, stmt.initializer.name
    assert_equal 3, stmt.initializer.args.length
  end

  test "parse field access" do
    source = "x = v.x\nreturn x"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FieldAccess, stmt.initializer
    assert_equal "x", stmt.initializer.field
  end

  test "emit to C" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :c)

    assert code.include?("vec3_new")
    assert code.include?("return color")
  end

  test "emit to MSL" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :msl)

    assert code.include?("float3")
    assert code.include?("return color")
  end

  test "emit to WGSL" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :wgsl)

    assert code.include?("vec3<f32>")
    assert code.include?("let color")
  end

  test "emit to GLSL" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :glsl)

    assert code.include?("vec3")
    assert code.include?("return color")
  end

  test "type inference for vec3" do
    source = "color = vec3(1.0, 0.0, 0.0)"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_equal :vec3, stmt.type
  end

  test "type inference for binary op with vectors" do
    source = <<~RUBY
      a = vec2(1.0, 2.0)
      b = a + a
    RUBY
    ir = @transpiler.parse_source(source)

    # Second statement should be vec2 type
    assert_equal :vec2, ir.statements[1].type
  end

  test "TARGETS constant contains all emitters" do
    targets = RLSL::Prism::Transpiler::TARGETS
    assert_equal RLSL::Prism::Emitters::CEmitter, targets[:c]
    assert_equal RLSL::Prism::Emitters::MSLEmitter, targets[:msl]
    assert_equal RLSL::Prism::Emitters::WGSLEmitter, targets[:wgsl]
    assert_equal RLSL::Prism::Emitters::GLSLEmitter, targets[:glsl]
  end

  test "initialize stores uniforms and custom_functions" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float }, { helper: { returns: :float } })
    assert_equal({ time: :float }, transpiler.uniforms)
    assert_equal({ helper: { returns: :float } }, transpiler.custom_functions)
  end

  test "emit raises error without parsing first" do
    transpiler = RLSL::Prism::Transpiler.new
    assert_raise(RuntimeError) do
      transpiler.emit(:c)
    end
  end

  test "emit raises error for unknown target" do
    @transpiler.parse_source("x = 1.0\nreturn x")
    assert_raise(RuntimeError) do
      @transpiler.emit(:unknown_target)
    end
  end

  test "emit accepts target as string" do
    @transpiler.parse_source("x = 1.0\nreturn x")
    result = @transpiler.emit("c")
    assert_kind_of String, result
  end

  test "emit accepts an explicit compilation unit" do
    compilation = @transpiler.compile_source("x = 1.0\nreturn x")
    result = @transpiler.emit(:c, compilation: compilation)

    assert_kind_of String, result
    assert_include result, "return x"
  end

  test "transpile_source combines parse and emit" do
    result = @transpiler.transpile_source("x = 1.0\nreturn x", :c)
    assert result.include?("1.0f")
  end

  test "parse_source registers frag_coord and resolution" do
    @transpiler.parse_source("return frag_coord")
    # Should not raise - frag_coord is registered
    result = @transpiler.emit(:c)
    assert result.include?("frag_coord")
  end

  test "parse_source handles empty body" do
    @transpiler.parse_source("return 0.0")
    result = @transpiler.emit(:c)
    assert result.include?("return 0.0f")
  end

  test "parse_source raises for invalid builtin function calls" do
    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.parse_source("x = sin(vec2(1.0, 2.0))\nreturn x")
    end

    assert_include error.message, "expected float, got vec2"
  end

  test "emit raises for target-unsupported builtin" do
    error = assert_raise(RLSL::Prism::TargetCapabilityError) do
      @transpiler.transpile_source("m = mat2(1.0)\nreturn determinant(m)", :c)
    end

    assert_include error.message, "Builtin determinant is not supported on C"
  end

  test "emit raises for target-unsupported uniform types used by builtins" do
    transpiler = RLSL::Prism::Transpiler.new({ texture: :sampler2D })

    error = assert_raise(RLSL::Prism::TargetCapabilityError) do
      transpiler.transpile_source("color = texture2D(u.texture, vec2(0.0, 0.0))\nreturn color", :msl)
    end

    assert_include error.message, "sampler2D"
  end

  test "emit with needs_return false" do
    @transpiler.parse_source("x = 1.0\nreturn x")
    result = @transpiler.emit(:c, needs_return: false)
    assert_kind_of String, result
  end

  test "compile_helpers strips parameters before inference" do
    transpiler = RLSL::Prism::Transpiler.new
    block = proc do |uv|
      uv
    end

    compilation = transpiler.compile_helpers(block)

    assert_equal [], compilation.source_unit.params
    assert_kind_of RLSL::Prism::IR::Block, compilation.ir
  end
end
