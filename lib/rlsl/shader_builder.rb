# frozen_string_literal: true

require_relative "shader_builder/shader_definition"
require_relative "shader_builder/build_service"
require_relative "shader_builder/source_resolver"
require_relative "shader_builder/native_extension_compiler"

module RLSL
  class ShaderBuilder
    attr_reader :name

    def initialize(name, definition = ShaderDefinition.new)
      @name = name.to_s
      @definition = definition
    end

    def uniforms(&block)
      if block_given?
        ctx = UniformContext.new
        ctx.instance_eval(&block)
        @definition = @definition.with_uniforms(ctx.uniforms)
      else
        @definition.uniforms
      end
    end

    def helpers(mode = :ruby, &block)
      @definition = @definition.with_helpers(mode: mode, block: block)
    end

    def functions(&block)
      ctx = FunctionContext.new
      ctx.instance_eval(&block)
      @definition = @definition.with_custom_functions(ctx.functions)
    end

    def fragment(&block)
      @definition = @definition.with_fragment(
        mode: block.arity > 0 ? :ruby : :c,
        block: block
      )
    end

    def compile_and_load
      build_service.compile_and_load
    end

    def build_metal_shader
      build_service.build_metal_shader
    end

    def build_wgsl_shader
      build_service.build_wgsl_shader
    end

    def build_glsl_shader(version: "450")
      build_service.build_glsl_shader(version: version)
    end

    def transpile_fragment(target)
      build_service.transpile_fragment(target)
    end

    def transpile_helpers(target)
      build_service.transpile_helpers(target)
    end

    private

    def build_service
      BuildService.new(@name, @definition)
    end
  end
end
