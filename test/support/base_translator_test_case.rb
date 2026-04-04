# frozen_string_literal: true

class BaseTranslatorTestTranslator < RLSL::BaseTranslator
  PROFILE = RLSL::BaseTranslator.build_profile(
    uniform_target: :wgsl,
    identifier_replacements: {
      "int" => "integer"
    },
    call_rewrites: {
      "test_func" => RLSL::BaseTranslator.rename_call("replaced_func")
    }
  )

  def generate_shader(helpers, fragment)
    "HELPERS: #{helpers}\nFRAGMENT: #{fragment}"
  end

  def target_vec2_type
    "test_vec2"
  end

  def target_vec3_type
    "test_vec3"
  end

  def target_vec4_type
    "test_vec4"
  end
end

class IncompleteBaseTranslator < RLSL::BaseTranslator
end

class ProfileOnlyBaseTranslator < RLSL::BaseTranslator
  PROFILE = RLSL::BaseTranslator.build_profile(
    uniform_target: :wgsl,
    identifier_replacements: {},
    call_rewrites: {}
  )
end
