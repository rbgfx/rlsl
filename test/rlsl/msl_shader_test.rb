# frozen_string_literal: true

require_relative "../test_helper"

class MSLShaderTest < Test::Unit::TestCase
  test "initializes with name, uniforms, and source" do
    uniforms = { time: :float, color: :vec3 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "// MSL source")

    assert_equal :test, shader.name
    assert_equal "// MSL source", shader.msl_source
  end

  test "metal? returns true" do
    shader = RLSL::MSL::Shader.new(:test, {}, "")
    assert_true shader.metal?
  end

  test "render delegates to render_metal" do
    shader = RLSL::MSL::Shader.new(:test, {}, "")
    captured_args = nil

    shader.define_singleton_method(:render_metal) do |*args|
      captured_args = args
    end

    shader.render(:handle, 640, 480, { time: 1.0 })

    assert_equal [:handle, 640, 480, { time: 1.0 }], captured_args
  end

  test "pack_uniforms packs float uniform" do
    uniforms = { time: :float }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { time: 1.5 }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms packs vec2 uniform" do
    uniforms = { pos: :vec2 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { pos: [1.0, 2.0] }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms packs vec3 uniform" do
    uniforms = { color: :vec3 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { color: [1.0, 0.5, 0.0] }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms packs vec4 uniform" do
    uniforms = { rgba: :vec4 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { rgba: [1.0, 0.5, 0.0, 1.0] }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms packs int uniform" do
    uniforms = { frame: :int }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { frame: 7 }, 800, 600)

    unpacked = data[8, 4].unpack("l")
    assert_equal [7], unpacked
  end

  test "pack_uniforms packs bool uniform as int" do
    uniforms = { enabled: :bool }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { enabled: true }, 800, 600)

    unpacked = data[8, 4].unpack("l")
    assert_equal [1], unpacked
  end

  test "pack_uniforms handles multiple uniforms" do
    uniforms = { time: :float, pos: :vec2, color: :vec3 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, {
      time: 1.0,
      pos: [100.0, 200.0],
      color: [1.0, 0.0, 0.0]
    }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms includes resolution at start" do
    shader = RLSL::MSL::Shader.new(:test, {}, "")

    data = shader.send(:pack_uniforms, {}, 800, 600)

    unpacked = data[0, 8].unpack("ff")
    assert_in_delta 800.0, unpacked[0], 0.01
    assert_in_delta 600.0, unpacked[1], 0.01
  end

  test "pack_uniforms raises when a required uniform is missing" do
    shader = RLSL::MSL::Shader.new(:test, { time: :float }, "")

    error = assert_raise(ArgumentError) do
      shader.send(:pack_uniforms, {}, 800, 600)
    end

    assert_include error.message, "Missing uniform :time"
  end

  test "pack_uniforms raises for invalid vector values" do
    shader = RLSL::MSL::Shader.new(:test, { color: :vec3 }, "")

    error = assert_raise(RLSL::UniformValueError) do
      shader.send(:pack_uniforms, { color: [1.0, 0.5] }, 800, 600)
    end

    assert_include error.message, "expected vec3"
  end
end
