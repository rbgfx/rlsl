# frozen_string_literal: true

require "set"

require_relative "ir/traversal"

module RLSL
  module Prism
    class MutationAnalyzer
      def analyze(node)
        assigned_names = IR::Traversal.each(node).filter_map do |current|
          next unless current.is_a?(IR::Assignment)
          next unless current.target.is_a?(IR::VarRef)

          current.target.name
        end.to_set

        IR::Traversal.each(node) do |current|
          next unless current.is_a?(IR::VarDecl)

          current.mutable = assigned_names.include?(current.name)
        end

        node
      end
    end
  end
end
