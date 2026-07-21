# frozen_string_literal: true

require_relative "../../test_helper"

class PrismIRTupleTypeTest < Test::Unit::TestCase
  test "TupleType stores types" do
    tuple = RLSL::Prism::IR::TupleType.new(:float, :float)
    assert_equal [:float, :float], tuple.types
  end

  test "TupleType to_sym generates symbol" do
    tuple = RLSL::Prism::IR::TupleType.new(:float, :vec2)
    assert_equal :tuple_float_vec2, tuple.to_sym
  end

  test "TupleType with multiple types" do
    tuple = RLSL::Prism::IR::TupleType.new(:float, :vec2, :vec3)
    assert_equal [:float, :vec2, :vec3], tuple.types
    assert_equal :tuple_float_vec2_vec3, tuple.to_sym
  end

  test "TupleType compares and hashes by its element types" do
    first = RLSL::Prism::IR::TupleType.new(:float, :vec2)
    equivalent = RLSL::Prism::IR::TupleType.new(:float, :vec2)
    different = RLSL::Prism::IR::TupleType.new(:float, :vec3)

    assert_equal first, equivalent
    assert_equal first.hash, equivalent.hash
    assert_not_equal first, different
  end

  test "TupleType has a useful inspect representation" do
    tuple = RLSL::Prism::IR::TupleType.new(:float, :vec2)

    assert_equal "#<RLSL::Prism::IR::TupleType [:float, :vec2]>", tuple.inspect
  end
end
