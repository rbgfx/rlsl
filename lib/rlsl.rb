# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "rlsl/version"
require_relative "rlsl/errors"
require_relative "rlsl/shader_name"
require_relative "rlsl/types"
require_relative "rlsl/uniform_context"
require_relative "rlsl/function_context"
require_relative "rlsl/code_generator"
require_relative "rlsl/runtime_shader"
require_relative "rlsl/compiled_shader"
require_relative "rlsl/base_translator"
require_relative "rlsl/msl/translator"
require_relative "rlsl/msl/uniform_buffer_packer"
require_relative "rlsl/msl/shader"
require_relative "rlsl/wgsl/translator"
require_relative "rlsl/glsl/translator"
require_relative "rlsl/prism/transpiler"
require_relative "rlsl/shader_builder"

module RLSL
  CACHE_DIR = File.join("rlsl", "compiled").freeze

  class << self
    def define(name, &block)
      build_shader(name, &block).compile_and_load
    end

    def define_metal(name, &block)
      build_shader(name, &block).build_metal_shader
    end

    def to_msl(name, &block)
      define_metal(name, &block).msl_source
    end

    def to_wgsl(name, &block)
      build_shader(name, &block).build_wgsl_shader
    end

    def to_glsl(name, version: "450", &block)
      build_shader(name, &block).build_glsl_shader(version: version)
    end

    def cache_dir
      @cache_dir ||= begin
        path = File.join(cache_root, CACHE_DIR)
        FileUtils.mkdir_p(path)
        path
      end
    end

    private

    def cache_root
      xdg_cache_home = ENV["XDG_CACHE_HOME"]
      return xdg_cache_home unless xdg_cache_home.to_s.empty?

      home = Dir.home
      return File.join(home, ".cache") unless home.to_s.empty?

      Dir.tmpdir
    rescue ArgumentError
      Dir.tmpdir
    end

    def build_shader(name, &block)
      builder = ShaderBuilder.new(name)
      builder.instance_eval(&block)
      builder
    end
  end

  module CompiledShaders
  end
end
