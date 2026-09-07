# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"

class ReviewRegressionsTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new
  end

  test "block parameters shadow fragment parameter aliases" do
    code = @transpiler.transpile_source(<<~RUBY, :glsl)
      |coord, size, uniforms|
      2.times do |coord|
        value = coord
      end
      vec3(coord.x, size.y, 0.0)
    RUBY

    assert_include code, "int value = coord"
    assert_not_include code, "int value = frag_coord"
  end

  test "all built-in-looking helper parameter names keep signature types" do
    signatures = {
      named: {
        returns: :float,
        params: { frag_coord: :float, resolution: :float, u: :float }
      }
    }
    code = @transpiler.transpile_helpers_source(
      "def named(frag_coord, resolution, u)\nfrag_coord + resolution + u\nend",
      :c,
      signatures
    )

    assert_include code, "float named(float frag_coord, float resolution, float u)"
    assert_include code, "return frag_coord + resolution + u"
  end

  test "uniforms may use the freeze member name" do
    transpiler = RLSL::Prism::Transpiler.new({ freeze: :float })

    assert_include transpiler.transpile_source("vec3(u.freeze)", :glsl), "u.freeze"
  end

  test "multiple assignment canonicalizes fragment aliases" do
    code = @transpiler.transpile_source(<<~RUBY, :glsl)
      |coord, size, uniforms|
      pair = [vec2(1.0), vec2(2.0)]
      coord, other = pair
      vec3(coord.x, other.y, 0.0)
    RUBY

    assert_include code, "frag_coord = pair[0]"
    assert_not_include code, "\ncoord = pair[0]"
  end

  test "WGSL tuple assignment uses WGSL temporary syntax" do
    transpiler = RLSL::Prism::Transpiler.new(
      {},
      { pair: { returns: %i[float float], params: { value: :float } } }
    )
    code = transpiler.transpile_source("a, b = pair(1.0)\nvec3(a, b, 0.0)", :wgsl)

    assert_match(/let (_rlsl_result\d+): pair_result = pair\(1.0\)/, code)
  end

  test "literal multiple assignment evaluates values before writing targets" do
    source = "a = 1.0\nb = 2.0\na, b = [b, a]\nvec3(a, b, 0.0)"

    %i[c glsl msl wgsl].each do |target|
      code = @transpiler.transpile_source(source, target)
      assert_match(/_rlsl_value\d+.*= b/, code)
      assert_match(/_rlsl_value\d+.*= a/, code)
      assert_match(/a = _rlsl_value\d+/, code)
      assert_match(/b = _rlsl_value\d+/, code)
    end
  end

  test "multiple assignment validates arity and existing target types" do
    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("a, b, c = [1.0, 2.0]")
    end
    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("a = 1.0\npair = [vec2(1.0), vec2(2.0)]\na, b = pair")
    end
    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("pair = [1.0]\na, b = pair")
    end
  end

  test "generated temporary names do not collide with source variables" do
    loop_code = @transpiler.transpile_source(
      "_rlsl_end0 = 5\nn = 2\nn.times { |_rlsl_i0| n -= 1 }\nvec3(n)",
      :c
    )
    assignment_code = @transpiler.transpile_source(
      "_rlsl_value0 = 3.0\na, b = [1.0, 2.0]\nvec3(a, b, _rlsl_value0)",
      :wgsl
    )

    assert_include loop_code, "int _rlsl_end1 = n"
    assert_include assignment_code, "let _rlsl_value1: f32"
  end

  test "shader fragments cannot return tuple-shaped arrays" do
    assert_raise(RLSL::Prism::ReturnFlowError) do
      @transpiler.transpile_source("[1.0, 2.0]", :c)
    end
    assert_raise(RLSL::Prism::ReturnFlowError) do
      @transpiler.transpile_source("return [1.0, 2.0]", :c)
    end
  end

  test "tuple return validation checks every element and arity" do
    signatures = { pair: { returns: %i[float vec2], params: {} } }

    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.transpile_helpers_source("def pair\n[1.0]\nend", :c, signatures)
    end
    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.transpile_helpers_source("def pair\n[1.0, vec3(1.0)]\nend", :c, signatures)
    end
  end

  test "C swizzles evaluate call receivers once" do
    transpiler = RLSL::Prism::Transpiler.new({}, { next_vec: { returns: :vec3, params: {} } })
    code = transpiler.transpile_source("next_vec().zyx", :c)

    assert_equal 1, code.scan("next_vec()").length
  end

  test "C mixed vector constructors evaluate each call once" do
    functions = {
      next_vec: { returns: :vec2, params: {} },
      next_value: { returns: :float, params: {} }
    }
    code = RLSL::Prism::Transpiler.new({}, functions).transpile_source(
      "vec3(next_vec(), next_value())",
      :c
    )

    assert_equal 1, code.scan("next_vec()").length
    assert_equal 1, code.scan("next_value()").length
  end

  test "times receivers are evaluated once" do
    transpiler = RLSL::Prism::Transpiler.new({}, { next_count: { returns: :int, params: {} } })
    code = transpiler.transpile_source("next_count().times { vec3(0.0) }\nvec3(1.0)", :c)

    assert_equal 1, code.scan("next_count()").length
  end

  test "declared return types check explicit and implicit branches" do
    signature = { shade: { returns: :float, params: { flag: :bool } } }

    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.transpile_helpers_source(
        "def shade(flag)\nreturn vec3(1.0) if flag\n0.0\nend",
        :c,
        signature
      )
    end
    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.transpile_helpers_source(
        "def shade(flag)\nif flag\n0.0\nelse\nvec3(1.0)\nend\nend",
        :c,
        signature
      )
    end
  end

  test "reviewed C semantics hold in a compiled native shader" do
    functions = {
      next_value: { returns: :float, params: {} },
      calls_ok: { returns: :float, params: {} }
    }
    helpers = <<~C
      static int review_calls = 0;
      static float next_value(void) { review_calls++; return 0.25f; }
      static float calls_ok(void) { return review_calls == 1 ? 1.0f : 0.0f; }
    C
    fragment = <<~RUBY
      n = 3
      hits = 0
      n.times do
        n -= 1
        hits += 1
      end
      sample = vec3(next_value())
      vec3(-1.0 % 2.0, hits / 3, calls_ok() + sample.x * 0.0)
    RUBY

    assert_equal [255, 255, 255, 255], render_native(:review_semantics, fragment, functions:, helpers:)
  end

  test "native shader cache preserves A B A renderer identity" do
    Dir.mktmpdir("rlsl-review-cache") do |cache_dir|
      colors = [
        "vec3(1.0, 0.0, 0.0)",
        "vec3(0.0, 1.0, 0.0)",
        "vec3(1.0, 0.0, 0.0)"
      ].map do |fragment|
        shader = compile_native(cache_dir, :review_same_name, fragment)
        buffer = "\0".b * 4
        shader.render(buffer, 1, 1)
        buffer.bytes
      end

      assert_equal [[0, 0, 255, 255], [0, 255, 0, 255], [0, 0, 255, 255]], colors
    end
  end

  test "all supported mixed C vector constructors compile and run" do
    fragment = <<~RUBY
      a = vec2(0.1)
      b = vec3(a, 0.2)
      c = vec3(0.2, a)
      d = vec4(a, a)
      e = vec4(b, 0.3)
      f = vec4(0.3, c)
      g = vec4(a, 0.2, 0.3)
      h = vec4(0.3, a, 0.2)
      i = vec4(0.2, 0.3, a)
      j = a.stst
      k = b.bgr
      l = d.qp
      vec3(e.y + f.z + g.w + h.x + i.y + j.z + k.x + l.y)
    RUBY

    assert_equal 4, render_native(:review_constructors, fragment).length
  end

  private

  def render_native(name, fragment, functions: {}, helpers: "")
    Dir.mktmpdir("rlsl-review") do |cache_dir|
      shader = compile_native(cache_dir, name, fragment, functions:, helpers:)
      buffer = "\0".b * 4
      shader.render(buffer, 1, 1)
      buffer.bytes
    end
  end

  def compile_native(cache_dir, name, fragment, functions: {}, helpers: "")
    fragment_code = RLSL::Prism::Transpiler.new({}, functions).transpile_source(fragment, :c)
    compiler = RLSL::ShaderBuilder::NativeExtensionCompiler.new(name, cache_dir: cache_dir)
    base_code = RLSL::CodeGenerator.new(name, {}, -> { helpers }, -> { fragment_code }).generate
    extension_name = compiler.extension_name_for(base_code)
    code = RLSL::CodeGenerator.new(
      name,
      {},
      -> { helpers },
      -> { fragment_code },
      extension_name: extension_name
    ).generate
    artifact = compiler.build(code, ext_name: extension_name)
    require artifact.file
    RLSL::CompiledShader.new(name, artifact.ext_name, {})
  end
end
