# frozen_string_literal: true

require "open3"
require "tmpdir"

require_relative "../test_helper"

class TargetCompilationTest < Test::Unit::TestCase
  test "generated GLSL passes glslangValidator" do
    require_command!("glslangValidator", "REQUIRE_GLSL_COMPILER")

    with_shader_file("shader.comp", generated_glsl) do |path, directory|
      assert_command_success("glslangValidator", "-V", path, "-o", File.join(directory, "shader.spv"))
    end
  end

  test "generated WGSL passes Naga validation" do
    require_command!("naga", "REQUIRE_WGSL_COMPILER")

    with_shader_file("shader.wgsl", generated_wgsl) do |path|
      assert_command_success("naga", path)
    end
  end

  test "WGSL with reassigned fragment aliases passes Naga validation" do
    require_command!("naga", "REQUIRE_WGSL_COMPILER")

    builder = RLSL::ShaderBuilder.new(:mutable_fragment_parameter)
    builder.fragment_source("|coord, size, data|\ncoord = coord / size\nvec3(coord.x, coord.y, 0.0)")
    with_shader_file("mutable-parameter.wgsl", builder.build_wgsl_shader) do |path|
      assert_command_success("naga", path)
    end
  end

  test "generated MSL passes the Metal compiler when installed" do
    unless metal_compiler_available?
      flunk("Metal compiler is required") if ENV["REQUIRE_MSL_COMPILER"] == "1"
      omit("Metal compiler is not installed")
    end

    with_shader_file("shader.metal", generated_msl) do |path, directory|
      assert_command_success("xcrun", "metal", "-c", path, "-o", File.join(directory, "shader.air"))
    end
  end

  private

  def shader_builder
    builder = RLSL::ShaderBuilder.new(:compiler_checked)
    builder.uniforms do
      float :time
      bool :enabled
      sampler2D :albedo
    end
    builder.fragment_source(<<~RUBY)
      |fc, size, uniforms|
      uv = fc / size
      sampled = textureLod(uniforms.albedo, uv, 0.0).xyz
      brightness = if uniforms.enabled
                     uniforms.time
                   else
                     1.0
                   end
      sampled * brightness
    RUBY
    builder
  end

  def generated_glsl
    shader_builder.build_glsl_shader
  end

  def generated_wgsl
    # WGSL intentionally rejects expression-level conditionals, so use an
    # equivalent branch-free fixture for its syntax/compiler integration.
    builder = RLSL::ShaderBuilder.new(:compiler_checked_wgsl)
    builder.uniforms do
      float :time
      sampler2D :albedo
    end
    builder.fragment_source(<<~RUBY)
      |fc, size, uniforms|
      uv = fc / size
      textureLod(uniforms.albedo, uv, 0.0).xyz * uniforms.time
    RUBY
    builder.build_wgsl_shader
  end

  def generated_msl
    shader_builder.build_metal_shader.msl_source
  end

  def with_shader_file(filename, source)
    Dir.mktmpdir("rlsl-shader-compile") do |directory|
      path = File.join(directory, filename)
      File.write(path, source)
      yield path, directory
    end
  end

  def require_command!(command, environment_flag)
    return if command_available?(command)

    flunk("#{command} is required") if ENV[environment_flag] == "1"
    omit("#{command} is not installed")
  end

  def command_available?(command)
    extensions = Gem.win_platform? ? ENV.fetch("PATHEXT", ".EXE").split(";") : [""]
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      extensions.any? { |extension| File.executable?(File.join(directory, "#{command}#{extension.downcase}")) ||
        File.executable?(File.join(directory, "#{command}#{extension.upcase}")) }
    end
  end

  def metal_compiler_available?
    return false unless command_available?("xcrun")

    _output, status = Open3.capture2e("xcrun", "metal", "--version")
    status.success?
  end

  def assert_command_success(*command)
    output, status = Open3.capture2e(*command)
    assert status.success?, "#{command.join(' ')} failed:\n#{output}"
  end
end
