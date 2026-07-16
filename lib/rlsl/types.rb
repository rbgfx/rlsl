# frozen_string_literal: true

require_relative "types/type_spec"
require_relative "types/catalog"
require_relative "types/target_resolver"
require_relative "types/value_normalizer"

module RLSL
  module UniformTypes
    extend Catalog
    extend TargetResolver
    extend ValueNormalizer
  end
end
