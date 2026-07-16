# frozen_string_literal: true

module RLSL
  module Prism
    class ScopeStack
      def initialize
        @scopes = [{}]
      end

      def push(initial_scope = {})
        @scopes << normalize(initial_scope)
      end

      def pop
        raise RLSL::InternalError, "Cannot pop the global scope" if @scopes.length == 1

        @scopes.pop
      end

      def register(name, type)
        @scopes.last[name.to_sym] = type
      end

      def lookup(name)
        @scopes.reverse_each do |scope|
          return scope[name.to_sym] if scope.key?(name.to_sym)
        end

        nil
      end

      def to_h
        @scopes.each_with_object({}) do |scope, merged|
          merged.merge!(scope)
        end
      end

      private

      def normalize(scope)
        scope.each_with_object({}) do |(name, type), normalized|
          normalized[name.to_sym] = type
        end
      end
    end
  end
end
