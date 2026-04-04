# frozen_string_literal: true

module RLSL
  module Prism
    class TypeEnvironment
      include TypeShapes

      ARRAY_ELEMENT_SUFFIX = "_element_type"

      def initialize
        @value_scopes = ScopeStack.new
        @array_element_scopes = ScopeStack.new
      end

      def push(initial_scope = {})
        value_scope = {}
        array_scope = {}

        normalize(initial_scope).each do |name, type|
          register_in_scopes(value_scope, array_scope, name, type)
        end

        @value_scopes.push(value_scope)
        @array_element_scopes.push(array_scope)
      end

      def pop
        @value_scopes.pop
        @array_element_scopes.pop
      end

      def register(name, type)
        register_in_scopes(@value_scopes, @array_element_scopes, name, type)
      end

      def lookup(name)
        normalized_name = name.to_sym
        return array_element_type(metadata_base_name(normalized_name)) if metadata_name?(normalized_name)

        @value_scopes.lookup(normalized_name)
      end

      def array_element_type(name)
        normalized_name = name.to_sym
        explicit_type = @array_element_scopes.lookup(normalized_name)
        return explicit_type if explicit_type

        value_type = @value_scopes.lookup(normalized_name)
        return TypeShapes.element_type(value_type) if TypeShapes.array?(value_type)

        nil
      end

      def to_h
        values = @value_scopes.to_h
        elements = @array_element_scopes.to_h.each_with_object({}) do |(name, type), memo|
          memo[metadata_name(name)] = type
        end

        values.each do |name, type|
          next unless TypeShapes.array?(type)

          elements[metadata_name(name)] ||= TypeShapes.element_type(type)
        end

        values.merge(elements)
      end

      private

      def register_in_scopes(value_scope, array_scope, name, type)
        normalized_name = name.to_sym

        if metadata_name?(normalized_name)
          write_scope(array_scope, metadata_base_name(normalized_name), type)
          return
        end

        write_scope(value_scope, normalized_name, type)
        return unless TypeShapes.array?(type)

        write_scope(array_scope, normalized_name, TypeShapes.element_type(type))
      end

      def normalize(scope)
        scope.each_with_object({}) do |(name, type), normalized|
          normalized[name.to_sym] = type
        end
      end

      def metadata_name?(name)
        name.to_s.end_with?(ARRAY_ELEMENT_SUFFIX)
      end

      def metadata_name(name)
        :"#{name}#{ARRAY_ELEMENT_SUFFIX}"
      end

      def metadata_base_name(name)
        name.to_s.delete_suffix(ARRAY_ELEMENT_SUFFIX).to_sym
      end

      def write_scope(scope, name, type)
        if scope.respond_to?(:register)
          scope.register(name, type)
        else
          scope[name.to_sym] = type
        end
      end
    end
  end
end
