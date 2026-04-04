# frozen_string_literal: true

module RLSL
  class ShaderBuilder
    class ShaderDefinition
      attr_reader :uniforms, :custom_functions, :helpers_block, :helpers_mode, :fragment_block, :fragment_mode

      def initialize(
        uniforms: {},
        custom_functions: {},
        helpers_block: nil,
        helpers_mode: :c,
        fragment_block: nil,
        fragment_mode: :c
      )
        @uniforms = normalize_hash(uniforms)
        @custom_functions = normalize_hash(custom_functions)
        @helpers_block = helpers_block
        @helpers_mode = helpers_mode
        @fragment_block = fragment_block
        @fragment_mode = fragment_mode
      end

      def with_uniforms(uniforms)
        copy(uniforms: uniforms)
      end

      def with_custom_functions(custom_functions)
        copy(custom_functions: custom_functions)
      end

      def with_helpers(mode:, block:)
        copy(helpers_mode: mode, helpers_block: block)
      end

      def with_fragment(mode:, block:)
        copy(fragment_mode: mode, fragment_block: block)
      end

      def ruby_fragment?
        @fragment_mode == :ruby
      end

      def ruby_helpers?
        @helpers_mode == :ruby
      end

      private

      def copy(**overrides)
        self.class.new(
          uniforms: overrides.fetch(:uniforms, @uniforms),
          custom_functions: overrides.fetch(:custom_functions, @custom_functions),
          helpers_block: overrides.fetch(:helpers_block, @helpers_block),
          helpers_mode: overrides.fetch(:helpers_mode, @helpers_mode),
          fragment_block: overrides.fetch(:fragment_block, @fragment_block),
          fragment_mode: overrides.fetch(:fragment_mode, @fragment_mode)
        )
      end

      def normalize_hash(hash)
        hash.each_with_object({}) do |(name, value), normalized|
          normalized[name.to_sym] = value
        end.freeze
      end
    end
  end
end
