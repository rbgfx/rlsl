# frozen_string_literal: true

module RLSL
  IDENTIFIER_PATTERN = /\A[A-Za-z_][A-Za-z0-9_]*\z/
  SHADER_NAME_PATTERN = IDENTIFIER_PATTERN

  def self.validate_identifier!(name, context: "identifier")
    normalized = name.to_s
    return normalized if normalized.match?(IDENTIFIER_PATTERN)

    raise ArgumentError,
          "Invalid #{context} #{name.inspect}: use an ASCII identifier beginning with a letter or underscore"
  end

  def self.validate_shader_name!(name)
    validate_identifier!(name, context: "shader name")
  end
end
