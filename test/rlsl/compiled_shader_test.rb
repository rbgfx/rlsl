# frozen_string_literal: true

require_relative "../test_helper"

class CompiledShaderTest < Test::Unit::TestCase
  test "metal? returns false for CompiledShader" do
    # Create a mock render method in CompiledShaders
    RLSL::CompiledShaders.define_singleton_method(:test_shader_render) do |buffer, width, height|
      # Mock implementation
    end

    shader = RLSL::CompiledShader.new(:test_shader, "test_shader", [])
    assert_false shader.metal?
  ensure
    # Clean up mock method
    RLSL::CompiledShaders.singleton_class.remove_method(:test_shader_render) if RLSL::CompiledShaders.respond_to?(:test_shader_render)
  end

  test "initializes with name, ext_name, and uniform_names" do
    RLSL::CompiledShaders.define_singleton_method(:basic_shader_render) do |buffer, width, height|
    end

    shader = RLSL::CompiledShader.new(:basic_shader, "basic_shader", [:time])
    assert_false shader.metal?
  ensure
    RLSL::CompiledShaders.singleton_class.remove_method(:basic_shader_render) if RLSL::CompiledShaders.respond_to?(:basic_shader_render)
  end

  test "render calls render method with correct arguments" do
    call_args = nil

    RLSL::CompiledShaders.define_singleton_method(:render_test_render) do |*args|
      call_args = args
    end

    shader = RLSL::CompiledShader.new(:render_test, "render_test", [:time, :scale])
    buffer = "fake_buffer"
    uniforms = { time: 1.0, scale: 2.0 }

    shader.render(buffer, 800, 600, uniforms)

    assert_equal [buffer, 800, 600, 1.0, 2.0], call_args
  ensure
    RLSL::CompiledShaders.singleton_class.remove_method(:render_test_render) if RLSL::CompiledShaders.respond_to?(:render_test_render)
  end

  test "render passes uniforms in order of uniform_names" do
    call_args = nil

    RLSL::CompiledShaders.define_singleton_method(:order_test_render) do |*args|
      call_args = args
    end

    shader = RLSL::CompiledShader.new(:order_test, "order_test", [:b, :a, :c])
    buffer = "buf"
    uniforms = { a: 1.0, b: 2.0, c: 3.0 }

    shader.render(buffer, 100, 100, uniforms)

    # Order should follow uniform_names: [:b, :a, :c]
    assert_equal [buffer, 100, 100, 2.0, 1.0, 3.0], call_args
  ensure
    RLSL::CompiledShaders.singleton_class.remove_method(:order_test_render) if RLSL::CompiledShaders.respond_to?(:order_test_render)
  end

  test "render works with empty uniforms" do
    call_args = nil

    RLSL::CompiledShaders.define_singleton_method(:empty_uniforms_render) do |*args|
      call_args = args
    end

    shader = RLSL::CompiledShader.new(:empty_uniforms, "empty_uniforms", [])
    buffer = "buf"

    shader.render(buffer, 640, 480)

    assert_equal [buffer, 640, 480], call_args
  ensure
    RLSL::CompiledShaders.singleton_class.remove_method(:empty_uniforms_render) if RLSL::CompiledShaders.respond_to?(:empty_uniforms_render)
  end

  test "render raises when a required uniform is missing" do
    RLSL::CompiledShaders.define_singleton_method(:missing_uniform_render) do |*args|
    end

    shader = RLSL::CompiledShader.new(:missing_uniform, "missing_uniform", { time: :float, mouse: :vec2 })

    error = assert_raise(ArgumentError) do
      shader.render("buf", 320, 240, { time: 1.0 })
    end

    assert_include error.message, "Missing uniform :mouse"
  ensure
    RLSL::CompiledShaders.singleton_class.remove_method(:missing_uniform_render) if RLSL::CompiledShaders.respond_to?(:missing_uniform_render)
  end

  test "render normalizes typed uniforms before dispatch" do
    call_args = nil

    RLSL::CompiledShaders.define_singleton_method(:typed_uniforms_render) do |*args|
      call_args = args
    end

    shader = RLSL::CompiledShader.new(:typed_uniforms, "typed_uniforms", {
      frame: :int,
      enabled: :bool,
      mouse: :vec2
    })

    shader.render("buf", 320, 240, {
      frame: 3.0,
      enabled: 1,
      mouse: [10, 20]
    })

    assert_equal ["buf", 320, 240, 3, true, [10.0, 20.0]], call_args
  ensure
    RLSL::CompiledShaders.singleton_class.remove_method(:typed_uniforms_render) if RLSL::CompiledShaders.respond_to?(:typed_uniforms_render)
  end

  test "render raises for invalid vector uniform values" do
    RLSL::CompiledShaders.define_singleton_method(:invalid_uniform_render) do |*args|
    end

    shader = RLSL::CompiledShader.new(:invalid_uniform, "invalid_uniform", { color: :vec3 })

    error = assert_raise(RLSL::UniformValueError) do
      shader.render("buf", 320, 240, { color: [1.0, 0.5] })
    end

    assert_include error.message, "expected vec3"
  ensure
    RLSL::CompiledShaders.singleton_class.remove_method(:invalid_uniform_render) if RLSL::CompiledShaders.respond_to?(:invalid_uniform_render)
  end

  test "conversion errors are normalized without inspecting their message" do
    value = Object.new
    value.define_singleton_method(:to_f) { raise ArgumentError, "Invalid value for uniform spoof" }

    error = assert_raise(RLSL::UniformValueError) do
      RLSL::UniformTypes.normalize_value(:float, value, name: :amount)
    end

    assert_include error.message, "expected float"
    assert_not_include error.message, "spoof"
  end
end
