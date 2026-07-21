# frozen_string_literal: true

module RLSL
  class ShaderBuilder
    class BuildService
      def initialize(name, definition, source_resolver_class: SourceResolver, compiler_factory: nil)
        @name = name
        @definition = definition
        @source_resolver_class = source_resolver_class
        @compiler_factory = compiler_factory
      end

      def compile_and_load
        compiler = native_extension_compiler
        base_code = generate_c_code
        extension_name = compiler.extension_name_for(base_code)
        c_code = generate_c_code(extension_name: extension_name)
        artifact = compiler.build(c_code, ext_name: extension_name)

        require artifact.file
        CompiledShader.new(@name, artifact.ext_name, @definition.uniforms)
      end

      def build_metal_shader
        translator = MSL::Translator.new(@definition.uniforms, *translation_sources(:msl), name: @name)
        msl_source = translator.translate

        MSL::Shader.new(@name, @definition.uniforms, msl_source)
      end

      def build_wgsl_shader
        WGSL::Translator.new(@definition.uniforms, *translation_sources(:wgsl), name: @name).translate
      end

      def build_glsl_shader(version: "450")
        GLSL::Translator.new(
          @definition.uniforms,
          *translation_sources(:glsl),
          version: version,
          name: @name
        ).translate
      end

      def transpile_fragment(target)
        return "" unless @definition.fragment_block

        source_resolver.fragment_code(target)
      end

      def transpile_helpers(target)
        return "" unless @definition.helpers_block

        source_resolver.helpers_code(target)
      end

      private

      def generate_c_code(extension_name: @name)
        helpers_code, fragment_code = resolved_sources(:c)
        codegen = CodeGenerator.new(
          @name,
          @definition.uniforms,
          -> { helpers_code },
          -> { fragment_code },
          extension_name: extension_name
        )
        codegen.generate
      end

      def resolved_sources(target)
        source_resolver.sources_for(target)
      end

      def translation_sources(target)
        source_resolver.translation_sources_for(target)
      end

      def source_resolver
        @source_resolver ||= @source_resolver_class.new(@definition)
      end

      def native_extension_compiler
        @native_extension_compiler ||= if @compiler_factory
                                         @compiler_factory.call(@name)
                                       else
                                         NativeExtensionCompiler.new(@name)
                                       end
      end
    end
  end
end
