# frozen_string_literal: true

require "digest"
require "open3"
require "shellwords"

module RLSL
  class ShaderBuilder
    class NativeExtensionCompiler
      Artifact = Struct.new(:ext_name, :directory, :file, keyword_init: true)

      def initialize(
        shader_name,
        cache_dir: RLSL.cache_dir,
        ruby_bin: RbConfig.ruby,
        dylib_ext: RbConfig::CONFIG["DLEXT"],
        make_command: RbConfig::CONFIG["MAKE"] || "make",
        fast_math: false
      )
        @shader_name = RLSL.validate_shader_name!(shader_name)
        @cache_dir = cache_dir
        @ruby_bin = ruby_bin
        @dylib_ext = dylib_ext
        @make_command = Shellwords.split(make_command)
        @fast_math = fast_math
      end

      def build(c_code, ext_name: nil)
        resolved_ext_name = ext_name || declared_extension_name(c_code) || extension_name_for(c_code)
        artifact = artifact_for(c_code, ext_name: resolved_ext_name)
        FileUtils.mkdir_p(artifact.directory)
        File.open(File.join(artifact.directory, ".build.lock"), "w") do |lock|
          lock.flock(File::LOCK_EX)
          compile(artifact, c_code) unless File.exist?(artifact.file)
        end
        artifact
      end

      def extension_name_for(c_code)
        code_hash = Digest::SHA256.hexdigest(c_code)[0, 16]
        "#{@shader_name}_#{code_hash}"
      end

      private

      def artifact_for(c_code, ext_name: extension_name_for(c_code))
        validated_ext_name = RLSL.validate_identifier!(ext_name, context: "extension name")
        directory = File.join(@cache_dir, extension_name_for(c_code))

        Artifact.new(
          ext_name: validated_ext_name,
          directory: directory,
          file: File.join(directory, "#{validated_ext_name}.#{@dylib_ext}")
        )
      end

      def compile(artifact, c_code)
        File.write(File.join(artifact.directory, "#{artifact.ext_name}.c"), c_code)
        File.write(File.join(artifact.directory, "extconf.rb"), extconf_source(artifact.ext_name))

        run_command!(@ruby_bin, "extconf.rb", chdir: artifact.directory)
        run_command!(*@make_command, chdir: artifact.directory)
      end

      def declared_extension_name(c_code)
        c_code[/\bvoid\s+Init_([A-Za-z_][A-Za-z0-9_]*)\s*\(/, 1]
      end

      def extconf_source(ext_name)
        <<~RUBY
          require "mkmf"
          $CFLAGS << " -O3#{@fast_math ? ' -ffast-math' : ''}"
          if RUBY_PLATFORM =~ /darwin/
            $CFLAGS << " -fblocks"
          end
          create_makefile("#{ext_name}")
        RUBY
      end

      def run_command!(*args, chdir:)
        runner = lambda do
          stdout, stderr, status = Open3.capture3(*args, chdir: chdir)
          return if status.success?

          output = [stdout, stderr].reject(&:empty?).join("\n")
          raise RLSL::CompilationError, "#{args.first} failed for #{@shader_name}:\n#{output}"
        end

        if defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
          Bundler.with_unbundled_env { runner.call }
        else
          runner.call
        end
      end
    end
  end
end
