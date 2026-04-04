# frozen_string_literal: true

require "fileutils"
require "digest"
require "rbconfig"

require_relative "shader_builder/source_resolver"
require_relative "shader_builder/native_extension_compiler"

module RLSL
  class ShaderBuilder
    attr_reader :name

    def initialize(name)
      @name = name.to_s
      @uniforms = {}
      @fragment_mode = :c
      @helpers_mode = :c
      @custom_functions = {}
    end

    def uniforms(&block)
      if block_given?
        ctx = UniformContext.new
        ctx.instance_eval(&block)
        @uniforms = ctx.uniforms
        reset_source_resolver
      else
        @uniforms
      end
    end

    def helpers(mode = :ruby, &block)
      @helpers_block = block
      @helpers_mode = mode
      reset_source_resolver
    end

    def functions(&block)
      ctx = FunctionContext.new
      ctx.instance_eval(&block)
      @custom_functions = ctx.functions
      reset_source_resolver
    end

    def fragment(&block)
      @fragment_block = block
      @fragment_mode = block.arity > 0 ? :ruby : :c
      reset_source_resolver
    end

    def ruby_mode?
      @fragment_mode == :ruby
    end

    def compile_and_load
      c_code = generate_c_code
      artifact = native_extension_compiler.build(c_code)

      require artifact.file
      CompiledShader.new(@name, artifact.ext_name, @uniforms)
    end

    def build_metal_shader
      translator = MSL::Translator.new(@uniforms, *resolved_sources(:msl))
      msl_source = translator.translate

      MSL::Shader.new(@name, @uniforms, msl_source)
    end

    def build_wgsl_shader
      WGSL::Translator.new(@uniforms, *resolved_sources(:wgsl)).translate
    end

    def build_glsl_shader(version: "450")
      GLSL::Translator.new(@uniforms, *resolved_sources(:glsl), version: version).translate
    end

    def transpile_fragment(target)
      return "" unless @fragment_block

      source_resolver.fragment_code(target)
    end

    def transpile_helpers(target)
      return "" unless @helpers_block

      source_resolver.helpers_code(target)
    end

    def helpers_ruby_mode?
      @helpers_mode == :ruby
    end

    private

    def generate_c_code
      helpers_code, fragment_code = resolved_sources(:c)
      helpers_block = -> { helpers_code }
      fragment_block = -> { fragment_code }
      codegen = CodeGenerator.new(@name, @uniforms, helpers_block, fragment_block)
      codegen.generate
    end

    def resolved_sources(target)
      source_resolver.sources_for(target)
    end

    def source_resolver
      @source_resolver ||= SourceResolver.new(
        uniforms: @uniforms,
        custom_functions: @custom_functions,
        helpers_block: @helpers_block,
        helpers_mode: @helpers_mode,
        fragment_block: @fragment_block,
        fragment_mode: @fragment_mode
      )
    end

    def native_extension_compiler
      @native_extension_compiler ||= NativeExtensionCompiler.new(@name)
    end

    def reset_source_resolver
      @source_resolver = nil
    end
  end
end
