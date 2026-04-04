# frozen_string_literal: true

require_relative "../../test_helper"

class PrismSourceExtractorTest < Test::Unit::TestCase
  def setup
    @extractor = RLSL::Prism::SourceExtractor.new
  end

  test "extract_from_string returns source unchanged" do
    source = "x = 1.0"
    assert_equal source, @extractor.extract_from_string(source)
  end

  test "raises error for block without source location" do
    block = proc { }
    block.define_singleton_method(:source_location) { [nil, nil] }

    assert_raise(RLSL::Prism::SourceExtractor::SourceNotAvailable) do
      @extractor.extract(block)
    end
  end

  test "extract from do..end block" do
    block = proc do |x|
      y = x + 1.0
      y
    end
    source = @extractor.extract(block)
    assert source.include?("y = x + 1.0")
  end

  test "extract from brace block" do
    block = proc { |x| x + 1.0 }
    source = @extractor.extract(block)
    assert source.include?("x + 1.0")
  end

  test "extract block with parameters" do
    block = proc { |a, b, c| a + b + c }
    source = @extractor.extract(block)
    assert source.include?("|a, b, c|")
  end

  test "extract multiline block" do
    block = proc do
      x = 1.0
      y = 2.0
      z = x + y
      z
    end
    source = @extractor.extract(block)
    assert source.include?("x = 1.0")
    assert source.include?("y = 2.0")
    assert source.include?("z = x + y")
  end

  test "extract handles strings in code" do
    block = proc do
      s = "hello { world } do end"
      s
    end
    source = @extractor.extract(block)
    assert source.include?("hello { world } do end")
  end

  test "extract handles comments in code" do
    block = proc do
      x = 1.0 # This is { a comment with } braces
      x
    end
    source = @extractor.extract(block)
    assert source.include?("x = 1.0")
  end

  test "extract handles assigned if expressions" do
    block = proc do
      x = if true
            1.0
          else
            0.0
          end
      x
    end

    source = @extractor.extract(block)
    assert source.include?("x = if true")
    assert source.include?("else")
  end

  test "extract ignores modifier forms when counting nested blocks" do
    block = proc do
      x = 1.0 if true
      x
    end

    source = @extractor.extract(block)
    assert source.include?("x = 1.0 if true")
  end

  test "extract keeps outer block when nested blocks exist" do
    block = proc do
      values = [1.0].map do |x|
        x + 1.0
      end
      values
    end

    source = @extractor.extract(block)
    assert source.include?("values = [1.0].map do |x|")
    assert source.include?("x + 1.0")
    assert source.include?("values")
  end

  test "extract locates the block for the given source line" do
    proc do
      :first
    end

    block = proc do
      :second
    end

    source = @extractor.extract(block)
    assert source.include?(":second")
    assert_not_include source, ":first"
  end
end
