# frozen_string_literal: true

require_relative "../../test_helper"

class EmitterIntegrationTest < Test::Unit::TestCase
  test "full shader transpilation" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      x = sin(u.time)
      y = cos(u.time)
      color = vec3(x, y, 0.5)
      return color
    RUBY

    code = transpiler.transpile_source(source, :c)
    assert code.include?("sinf")
    assert code.include?("cosf")
    assert code.include?("vec3_new")
  end

  test "MSL emitter uses float types" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      color = vec3(1.0, 0.0, 0.0)
      return color
    RUBY

    code = transpiler.transpile_source(source, :msl)
    assert code.include?("float3")
    assert_false code.include?("vec3_new")
  end

  test "WGSL emitter uses f32 types" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      color = vec3(1.0, 0.0, 0.0)
      return color
    RUBY

    code = transpiler.transpile_source(source, :wgsl)
    assert code.include?("vec3<f32>")
    assert code.include?("let color")
  end

  test "WGSL emitter emits helper definitions with fn syntax" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(
        RLSL::Prism::IR::FuncCall.new(
          :vec3,
          [
            RLSL::Prism::IR::Literal.new(1.0, :float),
            RLSL::Prism::IR::Literal.new(0.0, :float),
            RLSL::Prism::IR::Literal.new(0.0, :float)
          ]
        )
      )
    ])
    function = RLSL::Prism::IR::FunctionDefinition.new(
      :helper_color,
      [],
      body,
      return_type: :vec3
    )

    result = emitter.emit(function)

    assert result.include?("fn helper_color() -> vec3<f32>")
  end

  test "GLSL emitter uses vec3" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      color = vec3(1.0, 0.0, 0.0)
      return color
    RUBY

    code = transpiler.transpile_source(source, :glsl)
    assert code.include?("vec3(")
  end
end
