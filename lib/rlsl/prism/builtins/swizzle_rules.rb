# frozen_string_literal: true

module RLSL
  module Prism
    module Builtins
      module SwizzleRules
        SWIZZLE_COMPONENTS = {
          "x" => 0, "r" => 0, "s" => 0,
          "y" => 1, "g" => 1, "t" => 1,
          "z" => 2, "b" => 2, "p" => 2,
          "w" => 3, "a" => 3, "q" => 3
        }.freeze

        SINGLE_COMPONENT_FIELDS = %w[x y z w r g b a s t p q].freeze
        SWIZZLE_PATTERNS = /\A[xyzwrgba]{2,4}\z/

        module_function

        def single_component_field?(name)
          SINGLE_COMPONENT_FIELDS.include?(name.to_s)
        end

        def swizzle?(name)
          name.to_s.match?(SWIZZLE_PATTERNS)
        end

        def swizzle_type(components)
          case components.length
          when 2 then :vec2
          when 3 then :vec3
          when 4 then :vec4
          else :float
          end
        end
      end
    end
  end
end
