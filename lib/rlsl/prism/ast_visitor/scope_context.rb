# frozen_string_literal: true

module RLSL
  module Prism
    class ASTVisitor
      class ScopeContext
        Scope = Struct.new(:params, :declared_vars)

        def initialize(params: [])
          @scopes = [build_scope(params)]
        end

        def with_scope(params: [])
          @scopes << build_scope(params)
          yield
        ensure
          @scopes.pop
        end

        def parameter?(name)
          @scopes.reverse_each.any? { |scope| scope.params.include?(name.to_sym) }
        end

        def root_parameter?(name)
          @scopes.first.params.include?(name.to_sym)
        end

        def declared?(name)
          @scopes.reverse_each.any? { |scope| scope.declared_vars.include?(name.to_sym) }
        end

        def known_variable?(name)
          parameter?(name) || declared?(name)
        end

        def declare(name)
          @scopes.last.declared_vars.add(name.to_sym)
        end

        private

        def build_scope(params)
          Scope.new(Set.new(Array(params).map(&:to_sym)), Set.new)
        end
      end
    end
  end
end
