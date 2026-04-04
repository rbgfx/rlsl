# frozen_string_literal: true

require_relative "../test_helper"

class ShaderBuilderTranspileTest < Test::Unit::TestCase
  test "transpile_fragment returns empty string without fragment block" do
    builder = RLSL::ShaderBuilder.new(:test)
    result = builder.transpile_fragment(:c)
    assert_equal "", result
  end

  test "transpile_helpers returns empty string without helpers block" do
    builder = RLSL::ShaderBuilder.new(:test)
    result = builder.transpile_helpers(:c)
    assert_equal "", result
  end

  test "transpile_fragment with ruby block" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    result = builder.transpile_fragment(:c)
    assert result.include?("vec3_new")
  end

  test "transpile_fragment to different targets" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    c_result = builder.transpile_fragment(:c)
    msl_result = builder.transpile_fragment(:msl)
    wgsl_result = builder.transpile_fragment(:wgsl)
    glsl_result = builder.transpile_fragment(:glsl)

    assert c_result.include?("vec3_new")
    assert msl_result.include?("float3")
    assert wgsl_result.include?("vec3<f32>")
    assert glsl_result.include?("vec3")
  end
end
