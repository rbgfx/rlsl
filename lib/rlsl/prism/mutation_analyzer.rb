# frozen_string_literal: true

require "set"

require_relative "ir/traversal"

module RLSL
  module Prism
    class MutationAnalyzer
      def analyze(node)
        assigned_names = IR::Traversal.each(node).filter_map do |current|
          case current
          when IR::Assignment
            current.target.name if current.target.is_a?(IR::VarRef)
          when IR::MultipleAssignment
            current.targets.select { |target| target.is_a?(IR::VarRef) }.map(&:name)
          end
        end.flatten.to_set

        IR::Traversal.each(node) do |current|
          next unless current.is_a?(IR::VarDecl)

          current.mutable = assigned_names.include?(current.name)
        end

        node
      end
    end
  end
end
