# frozen_string_literal: true

module RLSL
  module Prism
    CompilationUnit = Struct.new(:source_unit, :ir, keyword_init: true)
  end
end
