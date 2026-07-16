# frozen_string_literal: true

require_relative "code_generator/template_context"
require_relative "code_generator/math_prelude"
require_relative "code_generator/uniform_struct_generator"
require_relative "code_generator/shader_function_generator"
require_relative "code_generator/ruby_wrapper_generator"

module RLSL
  class CodeGenerator
    def initialize(name, uniforms, helpers_block, fragment_block)
      @context = TemplateContext.new(
        name: name,
        uniforms: uniforms,
        helpers_block: helpers_block,
        fragment_block: fragment_block
      )
    end

    def generate
      <<~C
        #include <ruby.h>
        #include <ruby/thread.h>
        #include <limits.h>
        #include <math.h>
        #include <stdint.h>
        #ifdef __APPLE__
        #include <dispatch/dispatch.h>
        #endif

        #{RLSL::C_TYPES}
        #{MathPrelude.code}
        #{UniformStructGenerator.new(@context).generate}
        #{custom_helpers}
        #{ShaderFunctionGenerator.new(@context).generate}
        #{RubyWrapperGenerator.new(@context).generate}

        #{init_function}
      C
    end

    private

    def custom_helpers
      @context.helpers_code
    end

    def init_function
      <<~C
        void Init_#{@context.name}(void) {
          VALUE mRLSL = rb_define_module("RLSL");
          VALUE mShaders = rb_define_module_under(mRLSL, "CompiledShaders");
          rb_define_module_function(mShaders, "#{@context.name}_render", shader_#{@context.name}_render, #{@context.render_arity});
        }
      C
    end
  end
end
