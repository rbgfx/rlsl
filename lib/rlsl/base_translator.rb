# frozen_string_literal: true

require_relative "base_translator/code_rewriter"

module RLSL
  class BaseTranslator
    SourceSnippet = Struct.new(:code, :format, keyword_init: true) do
      def target_code?
        format == :target
      end
    end

    TargetProfile = Struct.new(
      :uniform_target,
      :identifier_replacements,
      :call_rewrites,
      :removed_identifiers,
      keyword_init: true
    ) do
      def translate(code)
        CodeRewriter.new(code).rewrite(
          identifier_replacements: identifier_replacements,
          call_rewrites: call_rewrites,
          removed_identifiers: removed_identifiers
        )
      end
    end

    REMOVED_IDENTIFIERS = %w[static inline].freeze

    def initialize(uniforms, helpers_code, fragment_code)
      @uniforms = uniforms
      @helpers_source = normalize_source(helpers_code)
      @fragment_source = normalize_source(fragment_code)
    end

    def translate
      helpers_translated = translate_code(@helpers_source)
      fragment_translated = translate_code(@fragment_source)
      generate_shader(helpers_translated, fragment_translated)
    end

    protected

    def translate_code(source)
      snippet = normalize_source(source)
      return "" if snippet.code.empty?
      return snippet.code if snippet.target_code?

      profile.translate(snippet.code)
    end

    def generate_shader(_helpers, _fragment)
      raise NotImplementedError, "Subclasses must implement generate_shader"
    end

    def uniform_type_to_target(type)
      case type
      when :float then target_float_type
      when :int then target_int_type
      when :bool then target_bool_type
      when :vec2 then target_vec2_type
      when :vec3 then target_vec3_type
      when :vec4 then target_vec4_type
      when :mat2 then target_mat2_type
      when :mat3 then target_mat3_type
      when :mat4 then target_mat4_type
      when :sampler2D then target_sampler2d_type
      else
        raise ArgumentError, "Unsupported uniform type: #{type.inspect}"
      end
    end

    def target_float_type
      "float"
    end

    def target_int_type
      UniformTypes.target_type(:int, uniform_target)
    end

    def target_bool_type
      UniformTypes.target_type(:bool, uniform_target)
    end

    def target_vec2_type
      UniformTypes.target_type(:vec2, uniform_target)
    end

    def target_vec3_type
      UniformTypes.target_type(:vec3, uniform_target)
    end

    def target_vec4_type
      UniformTypes.target_type(:vec4, uniform_target)
    end

    def target_mat2_type
      UniformTypes.target_type(:mat2, uniform_target)
    end

    def target_mat3_type
      UniformTypes.target_type(:mat3, uniform_target)
    end

    def target_mat4_type
      UniformTypes.target_type(:mat4, uniform_target)
    end

    def target_sampler2d_type
      UniformTypes.target_type(:sampler2D, uniform_target)
    end

    def uniform_target
      profile.uniform_target
    end

    def uniform_lines(resolution_line:, &block)
      lines = [resolution_line]
      @uniforms.each do |name, type|
        lines << block.call(name, uniform_type_to_target(type))
      end
      lines
    end

    def indent_source(source, spaces)
      prefix = " " * spaces
      source.to_s.lines.map { |line| line.strip.empty? ? line : "#{prefix}#{line}" }.join.rstrip
    end

    def profile
      return self.class::PROFILE if self.class.const_defined?(:PROFILE, false)

      raise NotImplementedError, "Subclasses must define PROFILE"
    end

    def self.build_profile(uniform_target:, identifier_replacements:, call_rewrites:, removed_identifiers: REMOVED_IDENTIFIERS)
      TargetProfile.new(
        uniform_target: uniform_target,
        identifier_replacements: identifier_replacements.freeze,
        call_rewrites: call_rewrites.freeze,
        removed_identifiers: removed_identifiers.freeze
      ).freeze
    end

    def self.common_call_rewrites(target_vec2:, target_vec3:, target_vec4:)
      {
        "vec2_new" => rename_call(target_vec2),
        "vec3_new" => rename_call(target_vec3),
        "vec4_new" => rename_call(target_vec4),
        "vec2_add" => infix_call("+"),
        "vec3_add" => infix_call("+"),
        "vec2_sub" => infix_call("-"),
        "vec3_sub" => infix_call("-"),
        "vec2_mul" => infix_call("*"),
        "vec3_mul" => infix_call("*"),
        "vec2_div" => infix_call("/"),
        "vec3_div" => infix_call("/"),
        "vec2_dot" => rename_call("dot"),
        "vec3_dot" => rename_call("dot"),
        "vec2_length" => rename_call("length"),
        "vec3_length" => rename_call("length"),
        "vec2_normalize" => rename_call("normalize"),
        "vec3_normalize" => rename_call("normalize"),
        "sqrtf" => rename_call("sqrt"),
        "sinf" => rename_call("sin"),
        "cosf" => rename_call("cos"),
        "tanf" => rename_call("tan"),
        "fabsf" => rename_call("abs"),
        "fminf" => rename_call("min"),
        "fmaxf" => rename_call("max"),
        "floorf" => rename_call("floor"),
        "ceilf" => rename_call("ceil"),
        "powf" => rename_call("pow"),
        "expf" => rename_call("exp"),
        "logf" => rename_call("log"),
        "atan2f" => rename_call("atan2"),
        "fmodf" => rename_call("fmod"),
        "mix_f" => rename_call("mix"),
        "mix_v3" => rename_call("mix"),
        "clamp_f" => rename_call("clamp"),
        "smoothstep" => rename_call("smoothstep"),
        "fract" => rename_call("fract")
      }.freeze
    end

    def self.rename_call(name)
      lambda do |arguments|
        "#{name}(#{arguments.join(', ')})"
      end
    end

    def self.infix_call(operator)
      lambda do |arguments|
        raise ArgumentError, "Expected 2 arguments for #{operator} rewrite, got #{arguments.length}" unless arguments.length == 2

        "(#{arguments[0]} #{operator} #{arguments[1]})"
      end
    end

    private

    def normalize_source(source)
      return SourceSnippet.new(code: "", format: :legacy) if source.nil?
      return source if source.is_a?(SourceSnippet)

      SourceSnippet.new(code: source.to_s, format: :legacy)
    end
  end
end
