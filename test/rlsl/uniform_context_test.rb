# frozen_string_literal: true

require_relative "../test_helper"

class UniformContextTest < Test::Unit::TestCase
  test "initializes with empty uniforms" do
    ctx = RLSL::UniformContext.new
    assert_equal({}, ctx.uniforms)
  end

  test "float adds float uniform" do
    ctx = RLSL::UniformContext.new
    ctx.float(:time)
    assert_equal :float, ctx.uniforms[:time]
  end

  test "vec2 adds vec2 uniform" do
    ctx = RLSL::UniformContext.new
    ctx.vec2(:mouse)
    assert_equal :vec2, ctx.uniforms[:mouse]
  end

  test "vec3 adds vec3 uniform" do
    ctx = RLSL::UniformContext.new
    ctx.vec3(:camera)
    assert_equal :vec3, ctx.uniforms[:camera]
  end

  test "vec4 adds vec4 uniform" do
    ctx = RLSL::UniformContext.new
    ctx.vec4(:color)
    assert_equal :vec4, ctx.uniforms[:color]
  end

  test "int adds int uniform" do
    ctx = RLSL::UniformContext.new
    ctx.int(:frame)
    assert_equal :int, ctx.uniforms[:frame]
  end

  test "bool adds bool uniform" do
    ctx = RLSL::UniformContext.new
    ctx.bool(:enabled)
    assert_equal :bool, ctx.uniforms[:enabled]
  end

  test "rejects invalid uniform identifiers" do
    ctx = RLSL::UniformContext.new

    error = assert_raise(ArgumentError) { ctx.float(:"my-value") }
    assert_include error.message, "Invalid uniform name"
  end

  test "rejects reserved uniform names" do
    RLSL::UniformContext::RESERVED_NAMES.each do |name|
      error = assert_raise(ArgumentError) { RLSL::UniformContext.new.float(name) }
      assert_include error.message, "reserved"
    end
  end

  test "rejects duplicate uniform names" do
    ctx = RLSL::UniformContext.new
    ctx.float(:time)

    error = assert_raise(ArgumentError) { ctx.int("time") }
    assert_include error.message, "already defined"
  end

  test "rejects names used by generated texture samplers in either order" do
    texture_first = RLSL::UniformContext.new
    texture_first.sampler2D(:tex)
    error = assert_raise(ArgumentError) { texture_first.float(:tex_sampler) }
    assert_include error.message, "generated sampler name"

    sampler_first = RLSL::UniformContext.new
    sampler_first.float(:tex_sampler)
    error = assert_raise(ArgumentError) { sampler_first.sampler2D(:tex) }
    assert_include error.message, "generated sampler name"
  end
end
