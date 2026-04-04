# frozen_string_literal: true

require_relative "../../test_helper"

class PrismTranspilerCompilationTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new({ time: :float })
  end

  test "compile_source returns a stateless compilation unit" do
    compilation = @transpiler.compile_source("x = 1.0\nreturn x")

    assert_kind_of RLSL::Prism::CompilationUnit, compilation
    assert_kind_of RLSL::Prism::SourceUnit, compilation.source_unit
    assert_kind_of RLSL::Prism::IR::Block, compilation.ir
  end

  test "emit accepts an explicit compilation unit without session state" do
    transpiler = RLSL::Prism::Transpiler.new
    compilation = @transpiler.compile_source("x = 1.0\nreturn x")

    result = transpiler.emit(:c, compilation: compilation)

    assert_kind_of String, result
    assert_include result, "return x"
  end
end
