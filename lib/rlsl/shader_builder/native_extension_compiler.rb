# frozen_string_literal: true

module RLSL
  class ShaderBuilder
    class NativeExtensionCompiler
      Artifact = Struct.new(:ext_name, :directory, :file, keyword_init: true)

      def initialize(shader_name, cache_dir: RLSL.cache_dir, ruby_bin: RbConfig.ruby, dylib_ext: RbConfig::CONFIG["DLEXT"])
        @shader_name = shader_name
        @cache_dir = cache_dir
        @ruby_bin = ruby_bin
        @dylib_ext = dylib_ext
      end

      def build(c_code)
        artifact = artifact_for(c_code)
        compile(artifact, c_code) unless File.exist?(artifact.file)
        artifact
      end

      private

      def artifact_for(c_code)
        code_hash = Digest::MD5.hexdigest(c_code)[0..7]
        ext_name = "#{@shader_name}_#{code_hash}"
        directory = File.join(@cache_dir, ext_name)

        Artifact.new(
          ext_name: ext_name,
          directory: directory,
          file: File.join(directory, "#{@shader_name}.#{@dylib_ext}")
        )
      end

      def compile(artifact, c_code)
        FileUtils.mkdir_p(artifact.directory)

        File.write(File.join(artifact.directory, "#{artifact.ext_name}.c"), c_code)
        File.write(File.join(artifact.directory, "extconf.rb"), extconf_source(artifact.ext_name))

        Dir.chdir(artifact.directory) do
          system("#{@ruby_bin} extconf.rb > /dev/null 2>&1") or raise "extconf failed for #{artifact.ext_name}"
          system("/usr/bin/make > /dev/null 2>&1") or raise "make failed for #{artifact.ext_name}"
        end
      end

      def extconf_source(ext_name)
        <<~RUBY
          require "mkmf"
          $CFLAGS << " -O3 -ffast-math"
          if RUBY_PLATFORM =~ /darwin/
            $CFLAGS << " -fblocks"
          end
          create_makefile("#{ext_name}")
        RUBY
      end
    end
  end
end
