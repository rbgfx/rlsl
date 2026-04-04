# frozen_string_literal: true

module RLSL
  module Prism
    CompilationSession = Struct.new(:current, keyword_init: true) do
      def ir
        current&.ir
      end
    end
  end
end
