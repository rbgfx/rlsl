# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tmpdir"

require_relative "../test_helper"

class IssueRegressionsTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new
  end

  test "integer literals remain integers in loops" do
    source = "10.times do |i|\n  x = i\nend\nvec3(1.0)"

    assert_include @transpiler.transpile_source(source, :c), "for (int i = 0; i < 10;"
    assert_include @transpiler.transpile_source(source, :wgsl), "for (var i: i32 = 0; i < 10;"
  end

  test "WGSL uses var only for reassigned declarations" do
    code = @transpiler.transpile_source("total = 0.0\ntotal += 1.0\ncolor = vec3(total)\ncolor", :wgsl)

    assert_include code, "var total: f32"
    assert_include code, "let color: vec3<f32>"
  end

  test "operator assignment and unless preserve grouping" do
    operator_code = @transpiler.transpile_source(
      "x = 10.0\ny = 4.0\nz = 1.0\nx -= y - z\nvec3(x)",
      :c
    )
    unless_code = @transpiler.transpile_source(
      "a = 1.0\nunless a > 0.0 && a < 2.0\n  a = 3.0\nend\nvec3(a)",
      :c
    )

    assert_include operator_code, "x = x - (y - z)"
    assert_include unless_code, "if (!(a > 0.0f && a < 2.0f))"
  end

  test "unary operators are emitted before member access" do
    minus = @transpiler.transpile_source("x = 1.0\nvec3(-x)", :glsl)
    negate = @transpiler.transpile_source("flag = true\nif !flag\nvec3(0.0)\nelse\nvec3(1.0)\nend", :glsl)

    assert_include minus, "vec3(-x)"
    assert_include negate, "if (!flag)"
  end

  test "uniform fields take precedence over swizzle names" do
    transpiler = RLSL::Prism::Transpiler.new({ x: :float, rgb: :vec3 })

    assert_include transpiler.transpile_source("vec3(u.x)", :glsl), "u.x"
    assert_include transpiler.transpile_source("u.rgb", :glsl), "u.rgb"
  end

  test "fragment aliases stay canonical on writes and helper parameter types stay local" do
    fragment = @transpiler.transpile_source(
      "|coord, size, data|\ncoord = coord / size\ncoord += size\nvec3(coord.x, coord.y, 0.0)",
      :glsl
    )
    helper = @transpiler.transpile_helpers_source(
      "def identity(resolution)\nvalue = resolution\nvalue\nend",
      :c,
      { identity: { returns: :float, params: { resolution: :float } } }
    )

    assert_include fragment, "frag_coord = frag_coord / resolution"
    assert_include fragment, "frag_coord = frag_coord + (resolution)"
    assert_include helper, "float value = resolution"
  end

  test "inclusive and exclusive ranges use different comparisons" do
    inclusive = @transpiler.transpile_source("for i in 0..5\nend\nvec3(1.0)", :c)
    exclusive = @transpiler.transpile_source("for i in 0...5\nend\nvec3(1.0)", :c)

    assert_include inclusive, "i <= 5"
    assert_include exclusive, "i < 5"
  end

  test "loop bounds are captured before the body mutates them" do
    source = "n = 3\nhits = 0\nn.times do |i|\nn -= 1\nhits += 1\nend\nvec3(hits)"

    assert_match(/int (_rlsl_end\d+) = n;\nfor \(int i = 0; i < \1;/, @transpiler.transpile_source(source, :c))
    assert_match(/let (_rlsl_end\d+): i32 = n;\nfor \(var i: i32 = 0; i < \1;/,
                 @transpiler.transpile_source(source, :wgsl))
  end

  test "unsupported blocks are diagnosed instead of discarded" do
    error = assert_raise(RLSL::Prism::UnsupportedSyntaxError) do
      @transpiler.compile_source("values = [1.0]\nvalues.each do |value|\n  value\nend")
    end

    assert_include error.message, "only supported for Integer#times"
  end

  test "local arrays use target declaration syntax" do
    source = "values = [1.0, 2.0, 3.0]\nvec3(values[0], values[1], values[2])"

    assert_include @transpiler.transpile_source(source, :c), "float values[3] = {"
    assert_include @transpiler.transpile_source(source, :wgsl), "array<f32, 3>"
  end

  test "variables assigned by both branches are hoisted" do
    source = <<~RUBY
      condition = true
      if condition
        value = 2.0
      else
        value = 3.0
      end
      value = value + 1.0
      vec3(value)
    RUBY

    code = @transpiler.transpile_source(source, :c)
    assert_include code, "float value;\nif"
    assert_not_include code, "float value = value"
  end

  test "missing return paths and empty terminal conditionals are diagnosed" do
    assert_raise(RLSL::Prism::ReturnFlowError) do
      @transpiler.transpile_source("if true\n  vec3(1.0)\nend", :glsl)
    end
    assert_raise(RLSL::Prism::ReturnFlowError) do
      @transpiler.transpile_source("if true\nend", :glsl)
    end
  end

  test "swizzles validate families and receiver dimensions" do
    assert RLSL::Prism::Builtins.swizzle?("stpq")
    assert_false RLSL::Prism::Builtins.swizzle?("xg")

    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("v = vec2(1.0, 2.0)\nv.z")
    end
    assert_include error.message, "Invalid component"
  end

  test "C lowers component aliases and swizzles to real struct access" do
    code = @transpiler.transpile_source("v = vec3(0.1, 0.2, 0.3)\nvec3(v.r) + v.zyx", :c)

    assert_include code, "v.x"
    assert_include code, "vec3_swizzle3(v, 2, 1, 0)"
    assert_not_include code, "v.r"
    assert_not_include code, "v.zyx"
  end

  test "integer division is converted to float and C modulo follows floor semantics" do
    source = "a = 1\nb = 2\nratio = a / b\nvec3(ratio)"

    assert_include @transpiler.transpile_source(source, :c), "(float)(a) / (float)(b)"
    assert_include @transpiler.transpile_source(source, :wgsl), "f32(a) / f32(b)"
    assert_include @transpiler.transpile_source("vec3(-1.0 % 2.0)", :c), "rlsl_mod(-1.0f, 2.0f)"
  end

  test "multiple assignment distinguishes declarations from reassignments on C and WGSL" do
    source = "pair = [0.2, 0.3]\na, b = pair\na, b = pair\nvec3(a, b, 0.0)"
    c = @transpiler.transpile_source(source, :c)
    wgsl = @transpiler.transpile_source(source, :wgsl)

    assert_equal 1, c.scan("float a =").length
    assert_include c, "\na = pair[0]"
    assert_include wgsl, "var a: f32 = pair[0]"
    assert_include wgsl, "\na = pair[0]"
  end

  test "tuple helpers emit valid implicit and explicit returns and validate their types" do
    signatures = { pair: { returns: %i[float float], params: { value: :float } } }
    implicit = @transpiler.transpile_helpers_source("def pair(value)\n[value, value]\nend", :c, signatures)
    explicit = @transpiler.transpile_helpers_source("def pair(value)\nreturn [value, value]\nend", :wgsl, signatures)

    assert_include implicit, "return (pair_result){value, value}"
    assert_include explicit, "return pair_result(value, value)"
    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.transpile_helpers_source(
        "def bad_color\n0.5\nend",
        :c,
        { bad_color: { returns: :vec3, params: {} } }
      )
    end
    assert_include error.message, "returns :float, expected :vec3"
  end

  test "C vector splats evaluate their expression once" do
    transpiler = RLSL::Prism::Transpiler.new({}, { next_value: { returns: :float, params: {} } })
    code = transpiler.transpile_source("vec3(next_value())", :c)

    assert_equal 1, code.scan("next_value()").length
    assert_include code, "vec3_splat(next_value())"
  end

  test "vector size mismatches are rejected" do
    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("vec2(1.0) + vec3(1.0)")
    end

    assert_include error.message, "Vector size mismatch"
  end

  test "GLSL emits valid helper qualifiers and float modulo" do
    body = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Literal.new(1.0, :float)])
    function = RLSL::Prism::IR::FunctionDefinition.new(:helper, [], body, return_type: :float)
    function_code = RLSL::Prism::Emitters::GLSLEmitter.new.emit(function)
    modulo_code = @transpiler.transpile_source("x = 5.0 % 2.0\nvec3(x)", :glsl)

    assert_include function_code, "float helper()"
    assert_not_include function_code, "static inline"
    assert_include modulo_code, "mod(5.0, 2.0)"
  end

  test "GLSL versions reject source injection" do
    assert_raise(ArgumentError) do
      RLSL::GLSL::Translator.new({}, "", "", version: "450\n#error injected")
    end
  end

  test "translators do not inject an uv declaration" do
    fragment = "vec2 uv = frag_coord / resolution;\nreturn vec3(uv, 0.0);"

    glsl = RLSL::GLSL::Translator.new({}, "", fragment).translate
    wgsl_fragment = RLSL::BaseTranslator::SourceSnippet.new(code: fragment, format: :target)
    wgsl = RLSL::WGSL::Translator.new({}, "", wgsl_fragment).translate
    msl = RLSL::MSL::Translator.new({}, "", fragment).translate

    assert_equal 1, glsl.scan(/\buv =/).length
    assert_equal 1, wgsl.scan(/\buv =/).length
    assert_equal 1, msl.scan(/\buv =/).length
  end

  test "WGSL emits module declarations and host shareable bool uniforms" do
    compilation = @transpiler.compile_source("$steps = 4\nvec3(1.0)")
    globals = @transpiler.emit(:wgsl, compilation: compilation, needs_return: false)
    fragment = RLSL::BaseTranslator::SourceSnippet.new(code: "return vec3<f32>(1.0);", format: :target)
    shader = RLSL::WGSL::Translator.new({ enabled: :bool }, "", fragment).translate

    assert_include globals, "var<private> steps: i32 = 4"
    assert_include shader, "enabled: i32"
    assert_not_include shader, "};"
  end

  test "WGSL rejects eager conditional expression lowering" do
    source = "value = if true\n  1.0\nelse\n  2.0\nend\nvec3(value)"

    error = assert_raise(RLSL::Prism::TargetCapabilityError) do
      @transpiler.transpile_source(source, :wgsl)
    end
    assert_include error.message, "eager branch evaluation"
    assert_include error.message, "at (shader source):1:9"
  end

  test "MSL texture calls use a declared sampler and preserve LOD" do
    emitter = RLSL::Prism::Emitters::MSLEmitter.new
    call = RLSL::Prism::IR::FuncCall.new(
      :textureLod,
      [
        RLSL::Prism::IR::VarRef.new(:texture, :sampler2D),
        RLSL::Prism::IR::VarRef.new(:uv, :vec2),
        RLSL::Prism::IR::Literal.new(2.0, :float)
      ],
      nil,
      :vec4
    )

    code = emitter.emit(call)
    shader = RLSL::MSL::Translator.new({}, "", "return float3(1.0);").translate
    assert_include code, ".sample(rlsl_texture_sampler, uv, level(2.0))"
    assert_include shader, "constexpr sampler rlsl_texture_sampler"
  end

  test "texture uniforms become target resources rather than buffer fields" do
    outputs = %i[glsl wgsl msl].to_h do |target|
      builder = RLSL::ShaderBuilder.new(:texture_resources)
      builder.uniforms { sampler2D :albedo }
      builder.fragment_source(
        "|fc, size, uniforms|\ntexture2D(uniforms.albedo, fc / size).xyz"
      )
      output = case target
               when :glsl then builder.build_glsl_shader
               when :wgsl then builder.build_wgsl_shader
               when :msl then builder.build_metal_shader.msl_source
               end
      [target, output]
    end

    assert_include outputs[:glsl], "uniform sampler2D albedo"
    assert_include outputs[:glsl], "textureLod(albedo, frag_coord / resolution, 0.0)"
    assert_include outputs[:wgsl], "var albedo: texture_2d<f32>"
    assert_include outputs[:wgsl], "var albedo_sampler: sampler"
    assert_include outputs[:wgsl], "textureSampleLevel(albedo, albedo_sampler"
    assert_include outputs[:msl], "texture2d<float, access::sample> albedo [[texture(1)]]"
    assert_not_include outputs[:msl], "texture2d<float> albedo;"
  end

  test "C vector operations and constructors map to available functions" do
    source = <<~RUBY
      a = vec2(1.0, 2.0)
      b = vec2(3.0, 4.0)
      product = a * b
      scaled = 2.0 * product
      blended = mix(a, b, 0.5)
      angle = atan(1.0, 2.0)
      vec3(scaled.x + blended.y + angle)
    RUBY
    code = @transpiler.transpile_source(source, :c)

    assert_include code, "vec2_mul_components"
    assert_include code, "vec2_scalar_mul"
    assert_include code, "mix_v2"
    assert_include code, "atan2f"
    assert_include code, "vec3_splat("
  end

  test "two-argument arctangent uses each target's valid spelling" do
    source = "angle = atan(1.0, 2.0)\nvec3(angle)"

    assert_include @transpiler.transpile_source(source, :c), "atan2f(1.0f, 2.0f)"
    assert_include @transpiler.transpile_source(source, :glsl), "atan(1.0, 2.0)"
    assert_include @transpiler.transpile_source(source, :wgsl), "atan2(1.0, 2.0)"
    assert_include @transpiler.transpile_source(source, :msl), "atan2(1.0, 2.0)"
  end

  test "C rejects unavailable matrix constructors before compilation" do
    error = assert_raise(RLSL::Prism::TargetCapabilityError) do
      @transpiler.transpile_source("mat2(1.0)", :c)
    end
    assert_include error.message, "Builtin mat2 is not supported on C"
  end

  test "shader names are validated at every public build boundary" do
    assert_raise(ArgumentError) { RLSL::ShaderBuilder.new("../escape") }
    assert_raise(ArgumentError) do
      RLSL::CodeGenerator.new("bad-name", {}, nil, -> { "" }).generate
    end
    assert_raise(ArgumentError) do
      RLSL::ShaderBuilder::NativeExtensionCompiler.new("bad-name")
    end
  end

  test "generated native wrapper validates dimensions buffers and vector lengths" do
    code = RLSL::CodeGenerator.new(:safe_shader, { offset: :vec2 }, nil, -> {
      "return vec3_new(1.0f, 0.0f, 0.0f);"
    }).generate

    assert_include code, "RSTRING_LEN(rb_buffer) < required_bytes"
    assert_include code, "SIZE_MAX / width_size"
    assert_include code, "RARRAY_LEN(rb_offset) != 2"
    assert_include code, "rb_thread_call_without_gvl"
  end

  test "native extension rejects short buffers without writing" do
    Dir.mktmpdir("rlsl-native-test") do |cache_dir|
      fragment = @transpiler.transpile_source(<<~RUBY, :c)
        a = vec2(1.0, 2.0)
        b = vec2(3.0, 4.0)
        product = (a * 2.0) * (2.0 * b)
        blended = mix(a, b, 0.5)
        separation = distance(a, b)
        normal = cross(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0))
        negated = -normal
        angle = atan(1.0, 1.0)
        vec3(product.x + blended.y + separation, negated.z, angle).zyx
      RUBY
      code = RLSL::CodeGenerator.new(:buffer_shader, {}, nil, -> { fragment }).generate
      compiler = RLSL::ShaderBuilder::NativeExtensionCompiler.new(
        :buffer_shader,
        cache_dir: cache_dir
      )
      extension_name = compiler.extension_name_for(code)
      code = RLSL::CodeGenerator.new(
        :buffer_shader,
        {},
        nil,
        -> { fragment },
        extension_name: extension_name
      ).generate
      artifact = compiler.build(code, ext_name: extension_name)
      assert_native_buffer_contract(artifact.file, artifact.ext_name)
    end
  end

  test "Metal packing is little endian and bounded" do
    packer = RLSL::MSL::UniformBufferPacker.new(:packed, { frame: :int }, [:frame])
    data = packer.pack(2, 3, frame: 0x01020304)
    assert_equal [4, 3, 2, 1], data.byteslice(8, 4).bytes

    names = 70.times.map { |index| :"value_#{index}" }
    types = names.to_h { |name| [name, :float] }
    values = names.to_h { |name| [name, 1.0] }
    oversized = RLSL::MSL::UniformBufferPacker.new(:oversized, types, names)
    assert_raise(ArgumentError) { oversized.pack(1, 1, values) }
  end

  test "integer uniforms reject values outside signed 32-bit range" do
    packer = RLSL::MSL::UniformBufferPacker.new(:packed, { frame: :int }, [:frame])

    assert_raise(RLSL::UniformValueError) { packer.pack(1, 1, frame: 2**31) }
    assert_raise(RLSL::UniformValueError) { packer.pack(1, 1, frame: -2**31 - 1) }
    assert_nothing_raised { packer.pack(1, 1, frame: -2**31) }
    assert_nothing_raised { packer.pack(1, 1, frame: 2**31 - 1) }
  end

  test "fragment parameter types are positional and names emit canonically" do
    builder = RLSL::ShaderBuilder.new(:renamed_params)
    builder.uniforms { float :time }
    builder.fragment_source("|fc, size, uniforms|\nuv = fc / size\nvec3(uv.x, uv.y, uniforms.time)")

    code = builder.transpile_fragment(:glsl)
    assert_include code, "frag_coord / resolution"
    assert_include code, "u.time"
    assert_not_include code, "fc / size"
  end

  test "Ruby block source is captured when it is declared" do
    Dir.mktmpdir("rlsl-source-capture") do |directory|
      path = File.join(directory, "shader.rb")
      File.write(path, "proc { |coordinate| vec3(1.0, coordinate.x, 0.0) }\n")
      shader_block = eval(File.read(path), binding, path) # rubocop:disable Security/Eval
      builder = RLSL::ShaderBuilder.new(:captured_source)
      builder.fragment(&shader_block)

      File.write(path, "proc { |coordinate| vec3(0.0, coordinate.x, 0.0) }\n")

      code = builder.transpile_fragment(:glsl)
      assert_include code, "vec3(1.0, frag_coord.x, 0.0)"
      assert_not_include code, "vec3(0.0, frag_coord.x, 0.0)"
    end
  end

  test "no argument Ruby fragments have an explicit mode" do
    builder = RLSL::ShaderBuilder.new(:no_args)
    builder.fragment(:ruby) { vec3(1.0, 0.0, 0.0) }

    assert_include builder.transpile_fragment(:glsl), "vec3(1.0, 0.0, 0.0)"
  end

  test "helper functions require complete signatures" do
    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("def helper(value)\n  value\nend")
    end
    assert_include error.message, "requires an explicit signature"
  end

  test "receiver custom calls include the receiver in validation" do
    transpiler = RLSL::Prism::Transpiler.new(
      {},
      { scale: { returns: :float, params: { vector: :vec2, amount: :float } } }
    )
    code = transpiler.transpile_source("v = vec2(1.0)\nresult = v.scale(2.0)\nvec3(result)", :glsl)

    assert_include code, "scale(v, 2.0)"
  end

  test "unknown fields and lossy Ruby forms are rejected" do
    assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("v = vec2(1.0)\nv.unknown")
    end
    assert_raise(RLSL::Prism::UnsupportedSyntaxError) do
      @transpiler.compile_source("a, *b = [1.0, 2.0]")
    end
    assert_raise(RLSL::Prism::UnsupportedSyntaxError) do
      @transpiler.compile_source("return 1.0, 2.0")
    end
    assert_raise(RLSL::Prism::UnsupportedSyntaxError) do
      @transpiler.compile_source("|value = 1.0|\nvec3(value)")
    end
    assert_raise(RLSL::Prism::UnsupportedSyntaxError) do
      RLSL::ShaderBuilder.new(:rest_parameter).fragment { |*values| vec3(values[0]) }
    end
  end

  test "quoted parsing counts consecutive backslashes" do
    source = 'fn("a\\\\", 1)'
    arguments, = RLSL::BaseTranslator::CallParser.extract_group(source, 2)

    assert_equal ['"a\\\\"', " 1"], RLSL::BaseTranslator::CallParser.split_arguments(arguments)
  end

  test "IR traversal handles deeply nested expressions iteratively" do
    root = RLSL::Prism::IR::Literal.new(1.0)
    10_000.times { root = RLSL::Prism::IR::Parenthesized.new(root) }

    assert_equal 10_001, RLSL::Prism::IR::Traversal.each(root).count
  end

  test "AST visitor rejects excessive nesting before exhausting the Ruby stack" do
    source = Array.new(RLSL::Prism::ASTVisitor::MAX_AST_DEPTH + 1, "1.0").join(" + ")

    error = assert_raise(RLSL::Prism::UnsupportedSyntaxError) do
      @transpiler.compile_source(source)
    end
    assert_include error.message, "nesting exceeds"
  end

  test "to_msl mirrors source-returning target APIs" do
    source = RLSL.to_msl(:source_api) do
      fragment(:ruby) { vec3(1.0, 0.0, 0.0) }
    end

    assert_kind_of String, source
    assert_include source, "kernel void compute_shader"
  end

  test "nested unary minus and mixed numeric expressions preserve values" do
    source = <<~RUBY
      x = 0.75
      y = - -x
      root = sqrt(2)
      blended = mix(0, 1, 0.5)
      largest = max(1, 1.5)
      chosen = false ? 1 : 2.5
      vec3(y + root, blended, largest + chosen)
    RUBY

    code = @transpiler.transpile_source(source, :c)

    assert_include code, "float y = -(-x)"
    assert_include code, "float root = sqrtf((float)(2))"
    assert_include code, "float blended = mix_f((float)(0), (float)(1), 0.5f)"
    assert_include code, "float largest = fmaxf((float)(1), 1.5f)"
    assert_include code, "float chosen = (0 ? (float)(1) : 2.5f)"
  end

  test "mixed numeric arrays use a common element type" do
    source = "values = [1, 2.5]\nvec3(values[0], values[1], 0.0)"

    assert_include @transpiler.transpile_source(source, :c),
                   "float values[2] = {(float)(1), 2.5f}"
    assert_include @transpiler.transpile_source(source, :wgsl),
                   "array<f32, 2>(f32(1), 2.5)"

    error = assert_raise(RLSL::Prism::SignatureError) do
      @transpiler.compile_source("values = [true, 1.0]\nvec3(0.0)")
    end
    assert_include error.message, "Array elements have incompatible types"
  end

  test "branch declarations and loop binders follow their generated scopes" do
    branch = @transpiler.transpile_source(
      "if true\n  x = 1.0\nend\nx = 2.0\nvec3(x)",
      :c
    )
    loop_code = @transpiler.transpile_source(
      "for i in 0...4\n  i += 1\nend\nvec3(0.0)",
      :c
    )
    collision = @transpiler.transpile_source(
      "_rlsl_i0 = 0.25\n2.times { _rlsl_i0 }\nvec3(_rlsl_i0)",
      :c
    )
    while_scope = @transpiler.transpile_source(
      "while false\n  x = 1.0\nend\nx = 2.0\nvec3(x)",
      :wgsl
    )

    assert_include branch, "}\nfloat x = 2.0f"
    assert_match(/for \(int (_rlsl_i\d+) = 0; \1 < 4; \1\+\+\).*int i = \1.*i = i \+ \(1\)/m,
                 loop_code)
    assert_include collision, "for (int _rlsl_i1 = 0"
    assert_include while_scope, "}\nlet x: f32 = 2.0"
  end

  test "C vector negation uses component-wise multiplication" do
    code = @transpiler.transpile_source("v = vec3(0.25, 0.5, 0.75)\n-v", :c)

    assert_include code, "vec3_mul_scalar(v, -1.0f)"
    assert_not_include code, "return -v"
  end

  test "WGSL emits mutable locals casts and texture sampler parameters" do
    signatures = {
      bump: { returns: :float, params: { x: :float } },
      sample_color: { returns: :vec4, params: { tex: :sampler2D, uv: :vec2 } }
    }
    transpiler = RLSL::Prism::Transpiler.new({ albedo: :sampler2D }, signatures)
    helpers = transpiler.transpile_helpers_source(<<~RUBY, :wgsl, signatures)
      def bump(x)
        x = x + 1.0
        x
      end

      def sample_color(tex, uv)
        texture(tex, uv)
      end
    RUBY
    fragment = transpiler.transpile_source(<<~RUBY, :wgsl)
      a = 0.25
      b = 0.75
      a, b = [b, a]
      x = 0.0
      i = 1
      x = i
      angle = atan(0.5, 1.0)
      sample_color(u.albedo, vec2(a + x + angle, b)).xyz + vec3(bump(x))
    RUBY

    assert_match(/fn bump\((_rlsl_param\d+): f32\).*var x: f32 = \1/m, helpers)
    assert_match(/tex: texture_2d<f32>, (_rlsl_sampler\d+): sampler/, helpers)
    assert_match(/tex: texture_2d<f32>, (_rlsl_sampler\d+): sampler.*textureSampleLevel\(tex, \1/m, helpers)
    assert_include fragment, "var a: f32"
    assert_include fragment, "var b: f32"
    assert_include fragment, "x = f32(i)"
    assert_include fragment, "atan2(0.5, 1.0)"
    assert_include fragment, "sample_color(albedo, albedo_sampler"
  end

  test "WGSL-generated module and sampler names cannot collide with source names" do
    helper_collision = RLSL::ShaderBuilder.new(:helper_collision)
    helper_collision.uniforms { sampler2D :albedo }
    helper_collision.functions do
      define :sample_color,
             returns: :vec4,
             params: { tex: :sampler2D, tex_sampler: :float, uv: :vec2 }
    end
    helper_collision.helpers_source(<<~RUBY)
      def sample_color(tex, tex_sampler, uv)
        texture(tex, uv) * tex_sampler
      end
    RUBY
    helper_collision.fragment_source("sample_color(u.albedo, 1.0, frag_coord / resolution).xyz")

    code = helper_collision.build_wgsl_shader
    assert_match(/tex: texture_2d<f32>, (_rlsl_sampler\d+): sampler, tex_sampler: f32/, code)
    assert_match(/textureSampleLevel\(tex, (_rlsl_sampler\d+),/, code)

    reserved = RLSL::ShaderBuilder.new(:reserved_resource)
    reserved.uniforms { sampler2D :output_texture }
    reserved.fragment_source("vec3(0.0)")
    error = assert_raise(ArgumentError) { reserved.build_wgsl_shader }
    assert_include error.message, "WGSL module name conflict: output_texture"

    reassigned = RLSL::Prism::Transpiler.new(
      {},
      { replace: { returns: :sampler2D, params: { tex: :sampler2D } } }
    )
    error = assert_raise(RLSL::Prism::TargetCapabilityError) do
      reassigned.transpile_helpers_source("def replace(tex)\ntex = tex\ntex\nend", :wgsl,
                                          { replace: { returns: :sampler2D, params: { tex: :sampler2D } } })
    end
    assert_include error.message, "texture parameter tex cannot be reassigned"
  end

  private

  def assert_native_buffer_contract(extension_file, extension_name)
    script = <<~'RUBY'
      require ARGV.fetch(0)
      renderer = RLSL::CompiledShaders.method("#{ARGV.fetch(1)}_render")

      begin
        renderer.call("abc".b, 1, 1)
      rescue ArgumentError
        # Expected: the renderer must reject a buffer shorter than four bytes.
      else
        abort "short buffer was accepted"
      end

      renderer.call("abcd".b, 1, 1)
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, "-e", script, extension_file, extension_name)

    assert status.success?, output
  end
end
