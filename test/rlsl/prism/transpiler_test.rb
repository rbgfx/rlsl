# frozen_string_literal: true

require_relative "../../test_helper"

class PrismTranspilerTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new({ time: :float })
  end

  test "parse simple variable declaration" do
    source = "x = 1.0\nreturn x"
    ir = compile_source(source)

    assert_kind_of RLSL::Prism::IR::Block, ir
    assert_equal 2, ir.statements.length
    assert_kind_of RLSL::Prism::IR::VarDecl, ir.statements.first
  end

  test "parse binary operation" do
    source = "x = 1.0 + 2.0\nreturn x"
    ir = compile_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::VarDecl, stmt
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
    assert_equal "+", stmt.initializer.operator
  end

  test "parse function call" do
    source = "x = sin(0.5)\nreturn x"
    ir = compile_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :sin, stmt.initializer.name
  end

  test "parse vec3 constructor" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    ir = compile_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :vec3, stmt.initializer.name
    assert_equal 3, stmt.initializer.args.length
  end

  test "parse field access" do
    source = "v = vec3(1.0, 2.0, 3.0)\nx = v.x\nreturn x"
    ir = compile_source(source)

    stmt = ir.statements[1]
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
    ir = compile_source(source)

    stmt = ir.statements.first
    assert_equal :vec3, stmt.type
  end

  test "type inference for binary op with vectors" do
    source = <<~RUBY
      a = vec2(1.0, 2.0)
      b = a + a
    RUBY
    ir = compile_source(source)

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

  test "emit raises error for unknown target" do
    compilation = @transpiler.compile_source("x = 1.0\nreturn x")
    assert_raise(RLSL::Error) do
      @transpiler.emit(:unknown_target, compilation: compilation)
    end
  end

  test "emit accepts target as string" do
    compilation = @transpiler.compile_source("x = 1.0\nreturn x")
    result = @transpiler.emit("c", compilation: compilation)
    assert_kind_of String, result
  end

  test "transpile_source combines parse and emit" do
    result = @transpiler.transpile_source("x = 1.0\nreturn x", :c)
    assert result.include?("1.0f")
  end

  test "compile_source registers frag_coord and resolution" do
    compilation = @transpiler.compile_source("return frag_coord")
    result = @transpiler.emit(:c, compilation: compilation)
    assert result.include?("frag_coord")
  end

  test "compile_source handles empty body" do
    compilation = @transpiler.compile_source("return 0.0")
    result = @transpiler.emit(:c, compilation: compilation)
    assert result.include?("return 0.0f")
  end

  test "compile_source raises for invalid builtin function calls" do
    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("x = sin(vec2(1.0, 2.0))\nreturn x")
    end

    assert_include error.message, "expected float, got vec2"
  end

  test "IR nodes retain source locations after parameter extraction" do
    compilation = @transpiler.compile_source("|coordinate|\n\nvalue = coordinate.x\nvalue")
    declaration = compilation.ir.statements.first

    assert_equal "(shader source)", declaration.location.source_name
    assert_equal 3, declaration.location.line
    assert_equal 1, declaration.location.column
  end

  test "type errors report the most specific source location" do
    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("value = 1.0\nvector = vec2(value)\nvector.z")
    end

    assert_include error.message, "at (shader source):3:1"
  end

  test "target capability errors report their source location" do
    error = assert_raise(RLSL::Prism::TargetCapabilityError) do
      @transpiler.transpile_source("value = 1.0\nmat2(value)", :c)
    end

    assert_include error.message, "at (shader source):2:1"
  end

  test "Ruby block diagnostics retain the original file line" do
    block = proc do
      vector = vec2(1.0)
      vector.z
    end
    expected_line = block.source_location.last + 2

    error = assert_raise(RLSL::Prism::SignatureError) { @transpiler.compile_block(block) }

    assert_include error.message, block.source_location.first
    assert_include error.message, ":#{expected_line}:"
  end

  test "compile_source preserves int arithmetic for custom int parameters" do
    transpiler = RLSL::Prism::Transpiler.new(
      { time: :float },
      { get_color: { returns: :vec3, params: { i: :int } } }
    )

    source = <<~RUBY
      qx = 0
      qy = 0
      idx = qx + qy
      color = get_color(idx)
      return color
    RUBY

    ir = transpiler.compile_source(source).ir

    assert_equal :int, ir.statements[0].type
    assert_equal :int, ir.statements[1].type
    assert_equal :int, ir.statements[2].type
    assert_equal :vec3, ir.statements[3].type
  end

  test "emit raises for target-unsupported builtin" do
    error = assert_raise(RLSL::Prism::TargetCapabilityError) do
      @transpiler.transpile_source("m = mat2(1.0)\nreturn determinant(m)", :c)
    end

    assert_include error.message, "Builtin mat2 is not supported on C"
  end

  test "emit supports MSL texture uniforms as resources" do
    transpiler = RLSL::Prism::Transpiler.new({ texture: :sampler2D })

    code = transpiler.transpile_source("color = texture2D(u.texture, vec2(0.0, 0.0))\nreturn color", :msl)

    assert_include code, "texture.sample(rlsl_texture_sampler"
  end

  test "emit with needs_return false" do
    compilation = @transpiler.compile_source("x = 1.0\nreturn x")
    result = @transpiler.emit(:c, compilation: compilation, needs_return: false)
    assert_kind_of String, result
  end

  test "compile_helpers strips outer block parameters and rejects their use" do
    transpiler = RLSL::Prism::Transpiler.new
    block = proc do |uv|
      uv
    end

    error = assert_raise(RLSL::Prism::SignatureError) { transpiler.compile_helpers(block) }
    assert_include error.message, "Unknown shader function uv"
  end

  private

  def compile_source(source)
    @transpiler.compile_source(source).ir
  end
end
