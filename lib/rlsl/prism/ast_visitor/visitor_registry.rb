# frozen_string_literal: true

module RLSL
  module Prism
    class ASTVisitor
      class VisitorRegistry
        TRANSPARENT_NODES = [
          (::Prism::ArgumentsNode if defined?(::Prism::ArgumentsNode)),
          (::Prism::BlockParametersNode if defined?(::Prism::BlockParametersNode)),
          (::Prism::ParametersNode if defined?(::Prism::ParametersNode))
        ].compact.freeze

        def self.build(*visitor_maps)
          visitor_maps.each_with_object({}) do |visitor_map, merged|
            merged.merge!(visitor_map)
          end.freeze
        end
      end
    end
  end
end
