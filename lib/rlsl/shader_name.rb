# frozen_string_literal: true

module RLSL
  SHADER_NAME_PATTERN = /\A[A-Za-z_][A-Za-z0-9_]*\z/

  def self.validate_shader_name!(name)
    normalized = name.to_s
    return normalized if normalized.match?(SHADER_NAME_PATTERN)

    raise ArgumentError,
          "Invalid shader name #{name.inspect}: use an ASCII identifier beginning with a letter or underscore"
  end
end
