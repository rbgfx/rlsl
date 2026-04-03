# frozen_string_literal: true

require "fileutils"
require "digest"
require "rbconfig"

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
      else
        @uniforms
      end
    end

    def helpers(mode = :ruby, &block)
      @helpers_block = block
      @helpers_mode = mode
    end

    def functions(&block)
      ctx = FunctionContext.new
      ctx.instance_eval(&block)
      @custom_functions = ctx.functions
    end

    def fragment(&block)
      @fragment_block = block
      @fragment_mode = block.arity > 0 ? :ruby : :c
    end

    def ruby_mode?
      @fragment_mode == :ruby
    end

    def compile_and_load
      c_code = generate_c_code
      code_hash = Digest::MD5.hexdigest(c_code)[0..7]
      ext_name = "#{@name}_#{code_hash}"
      ext_dir = File.join(RLSL.cache_dir, ext_name)
      ext_file = File.join(ext_dir, "#{@name}.#{RbConfig::CONFIG['DLEXT']}")

      unless File.exist?(ext_file)
        compile_extension(@name, ext_dir, c_code)
      end

      require ext_file
      CompiledShader.new(@name, ext_name, @uniforms.keys)
    end

    def build_metal_shader
      helpers_code, fragment_code = resolved_sources(:msl)
      translator = MSL::Translator.new(@uniforms, helpers_code, fragment_code)
      msl_source = translator.translate

      MSL::Shader.new(@name, @uniforms, msl_source)
    end

    def build_wgsl_shader
      helpers_code, fragment_code = resolved_sources(:wgsl)
      translator = WGSL::Translator.new(@uniforms, helpers_code, fragment_code)
      translator.translate
    end

    def build_glsl_shader(version: "450")
      helpers_code, fragment_code = resolved_sources(:glsl)
      translator = GLSL::Translator.new(@uniforms, helpers_code, fragment_code, version: version)
      translator.translate
    end

    def transpile_fragment(target)
      return "" unless @fragment_block

      transpiler = Prism::Transpiler.new(@uniforms, @custom_functions)
      transpiler.transpile(@fragment_block, target)
    end

    def transpile_helpers(target)
      return "" unless @helpers_block

      transpiler = Prism::Transpiler.new(@uniforms, @custom_functions)
      transpiler.transpile_helpers(@helpers_block, target, @custom_functions)
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
      [resolved_helpers_code(target), resolved_fragment_code(target)]
    end

    def resolved_helpers_code(target)
      return "" unless @helpers_block
      return @helpers_block.call unless helpers_ruby_mode?

      transpile_helpers(target)
    end

    def resolved_fragment_code(target)
      return "" unless @fragment_block
      return @fragment_block.call unless ruby_mode?

      transpile_fragment(target)
    end

    def compile_extension(ext_name, ext_dir, c_code)
      FileUtils.mkdir_p(ext_dir)

      File.write(File.join(ext_dir, "#{ext_name}.c"), c_code)

      extconf = <<~RUBY
        require "mkmf"
        $CFLAGS << " -O3 -ffast-math"
        if RUBY_PLATFORM =~ /darwin/
          $CFLAGS << " -fblocks"
        end
        create_makefile("#{ext_name}")
      RUBY
      File.write(File.join(ext_dir, "extconf.rb"), extconf)

      Dir.chdir(ext_dir) do
        system("#{RbConfig.ruby} extconf.rb > /dev/null 2>&1") or raise "extconf failed for #{ext_name}"
        system("/usr/bin/make > /dev/null 2>&1") or raise "make failed for #{ext_name}"
      end
    end
  end
end
