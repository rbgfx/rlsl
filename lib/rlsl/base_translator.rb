# frozen_string_literal: true

module RLSL
  class BaseTranslator
    TargetProfile = Struct.new(
      :uniform_target,
      :type_map,
      :func_replacements,
      :code_transforms,
      keyword_init: true
    ) do
      def translate(code)
        result = code.dup

        type_map.each do |source_type, target_type|
          result.gsub!(/\b#{source_type}\b/, target_type)
        end

        func_replacements.each do |pattern, replacement|
          result.gsub!(pattern, replacement)
        end

        code_transforms.each { |transform| transform.call(result) }
        result
      end
    end

    FUNC_REPLACEMENTS = [].freeze
    TYPE_MAP = {}.freeze
    CODE_TRANSFORMS = [
      ->(code) { code.gsub!(/\bstatic\s+/, "") },
      ->(code) { code.gsub!(/\binline\s+/, "") }
    ].freeze

    def initialize(uniforms, helpers_code, fragment_code)
      @uniforms = uniforms
      @helpers_code = helpers_code || ""
      @fragment_code = fragment_code || ""
    end

    def translate
      helpers_translated = translate_code(@helpers_code)
      fragment_translated = translate_code(@fragment_code)
      generate_shader(helpers_translated, fragment_translated)
    end

    protected

    def translate_code(code)
      return "" if code.nil? || code.empty?

      profile.translate(code)
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
      return self.class.const_get(:PROFILE).uniform_target if self.class.const_defined?(:PROFILE, false)

      raise NotImplementedError, "Subclasses must implement uniform_target"
    end

    def uniform_lines(resolution_line:, &block)
      lines = [resolution_line]
      @uniforms.each do |name, type|
        lines << block.call(name, uniform_type_to_target(type))
      end
      lines
    end

    def profile
      return self.class.const_get(:PROFILE) if self.class.const_defined?(:PROFILE, false)

      @profile ||= self.class.build_profile(
        uniform_target: uniform_target,
        type_map: self.class::TYPE_MAP,
        func_replacements: self.class::FUNC_REPLACEMENTS
      )
    end

    def self.build_profile(uniform_target:, type_map:, func_replacements:, code_transforms: CODE_TRANSFORMS)
      TargetProfile.new(
        uniform_target: uniform_target,
        type_map: type_map.freeze,
        func_replacements: func_replacements.freeze,
        code_transforms: code_transforms.freeze
      ).freeze
    end

    def self.common_func_replacements(target_vec2:, target_vec3:, target_vec4:)
      [
        [/vec2_new\(([^,]+),\s*([^)]+)\)/, "#{target_vec2}(\\1, \\2)"],
        [/vec3_new\(([^,]+),\s*([^,]+),\s*([^)]+)\)/, "#{target_vec3}(\\1, \\2, \\3)"],
        [/vec4_new\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)/, "#{target_vec4}(\\1, \\2, \\3, \\4)"],
        [/vec2_add\(([^,]+),\s*([^)]+)\)/, '(\1 + \2)'],
        [/vec3_add\(([^,]+),\s*([^)]+)\)/, '(\1 + \2)'],
        [/vec2_sub\(([^,]+),\s*([^)]+)\)/, '(\1 - \2)'],
        [/vec3_sub\(([^,]+),\s*([^)]+)\)/, '(\1 - \2)'],
        [/vec2_mul\(([^,]+),\s*([^)]+)\)/, '(\1 * \2)'],
        [/vec3_mul\(([^,]+),\s*([^)]+)\)/, '(\1 * \2)'],
        [/vec2_div\(([^,]+),\s*([^)]+)\)/, '(\1 / \2)'],
        [/vec3_div\(([^,]+),\s*([^)]+)\)/, '(\1 / \2)'],
        [/vec2_dot\(([^,]+),\s*([^)]+)\)/, 'dot(\1, \2)'],
        [/vec3_dot\(([^,]+),\s*([^)]+)\)/, 'dot(\1, \2)'],
        [/vec2_length\(([^)]+)\)/, 'length(\1)'],
        [/vec3_length\(([^)]+)\)/, 'length(\1)'],
        [/vec2_normalize\(([^)]+)\)/, 'normalize(\1)'],
        [/vec3_normalize\(([^)]+)\)/, 'normalize(\1)'],
        [/sqrtf\(/, "sqrt("],
        [/sinf\(/, "sin("],
        [/cosf\(/, "cos("],
        [/tanf\(/, "tan("],
        [/fabsf\(/, "abs("],
        [/fminf\(/, "min("],
        [/fmaxf\(/, "max("],
        [/floorf\(/, "floor("],
        [/ceilf\(/, "ceil("],
        [/powf\(/, "pow("],
        [/expf\(/, "exp("],
        [/logf\(/, "log("],
        [/atan2f\(/, "atan2("],
        [/fmodf\(/, "fmod("],
        [/mix_f\(/, "mix("],
        [/mix_v3\(/, "mix("],
        [/clamp_f\(/, "clamp("],
        [/smoothstep\(/, "smoothstep("],
        [/fract\(/, "fract("]
      ]
    end
  end
end
