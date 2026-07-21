# frozen_string_literal: true

require_relative "../../test_helper"

class PrismSourceUnitTest < Test::Unit::TestCase
  test "from_source with parameters" do
    unit = RLSL::Prism::SourceUnit.from_source("|x, y|\nx + y")
    assert_equal [:x, :y], unit.params
    assert unit.body.include?("+")
  end

  test "from_source without parameters" do
    unit = RLSL::Prism::SourceUnit.from_source("x = 1.0\nreturn x")
    assert_equal [], unit.params
    assert unit.body.include?("x = 1.0")
  end

  test "from_source trims empty lines" do
    unit = RLSL::Prism::SourceUnit.from_source("\n\n  x = 1.0  \n\n")
    assert_equal "x = 1.0", unit.body.strip
  end

  test "from_source handles single line" do
    unit = RLSL::Prism::SourceUnit.from_source("return 1.0")
    assert_equal [], unit.params
    assert_equal "return 1.0", unit.body
  end

  test "without_params clears params and keeps body" do
    unit = RLSL::Prism::SourceUnit.from_source("|x|\nreturn x")
    helper_unit = unit.without_params

    assert_equal [], helper_unit.params
    assert_equal "return x", helper_unit.body
  end

  test "tracks source metadata and body line offsets" do
    unit = RLSL::Prism::SourceUnit.from_source(
      "\n|coordinate|\n\nvalue = coordinate.x\nvalue\n",
      source_name: "generated_shader.rb"
    )

    assert_equal "generated_shader.rb", unit.source_name
    assert_equal 3, unit.line_offset
    assert_equal 4, unit.line_offset + 1
  end

  test "without_params preserves source metadata" do
    unit = RLSL::Prism::SourceUnit.from_source("|x|\nreturn x", source_name: "helper.rb")
    helper_unit = unit.without_params

    assert_equal "helper.rb", helper_unit.source_name
    assert_equal unit.line_offset, helper_unit.line_offset
  end

  test "from_source keeps nested blocks in the body" do
    unit = RLSL::Prism::SourceUnit.from_source(<<~RUBY)
      values = [1.0].map do |x|
        x + 1.0
      end
      values
    RUBY

    assert_include unit.body, "values = [1.0].map do |x|"
    assert_include unit.body, "values"
  end

  test "from_source raises for invalid body" do
    assert_raise(RLSL::ParseError) do
      RLSL::Prism::SourceUnit.from_source("if")
    end
  end
end
