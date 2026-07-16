# frozen_string_literal: true

require_relative "shader_builder/shader_definition"
require_relative "shader_builder/build_service"
require_relative "shader_builder/source_resolver"
require_relative "shader_builder/native_extension_compiler"

module RLSL
  class ShaderBuilder
    attr_reader :name

    def initialize(name, definition = ShaderDefinition.new)
      @name = RLSL.validate_shader_name!(name)
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

    def uniform_types
      @definition.uniforms
    end

    def helpers(mode = :ruby, &block)
      @definition = @definition.with_helpers(mode: mode, block: block)
    end

    def functions(&block)
      ctx = FunctionContext.new
      ctx.instance_eval(&block)
      @definition = @definition.with_custom_functions(ctx.functions)
    end

    def fragment(mode = :auto, &block)
      raise ArgumentError, "fragment requires a block" unless block

      resolved_mode = if mode == :auto
                        block.parameters.empty? ? :c : :ruby
                      else
                        mode.to_sym
                      end
      unless %i[c ruby].include?(resolved_mode)
        raise ArgumentError, "fragment mode must be :c or :ruby"
      end

      @definition = @definition.with_fragment(
        mode: resolved_mode,
        block: block
      )
    end

    def fragment_source(source)
      @definition = @definition.with_fragment(mode: :ruby_source, block: -> { source.to_s })
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
