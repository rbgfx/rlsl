# frozen_string_literal: true

class BaseTranslatorTestTranslator < RLSL::BaseTranslator
  CALL_REWRITES = {
    "test_func" => RLSL::BaseTranslator.rename_call("replaced_func")
  }.freeze

  TYPE_MAP = {
    "int" => "integer"
  }.freeze

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

  def uniform_target
    :wgsl
  end
end

class IncompleteBaseTranslator < RLSL::BaseTranslator
end
