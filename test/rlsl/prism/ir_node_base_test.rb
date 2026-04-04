# frozen_string_literal: true

require_relative "../../test_helper"

class PrismIRNodeBaseTest < Test::Unit::TestCase
  test "Node#accept raises NotImplementedError" do
    node = RLSL::Prism::IR::Node.new
    assert_raise(NotImplementedError) do
      node.accept(nil)
    end
  end

  test "Node has type accessor" do
    node = RLSL::Prism::IR::Node.new
    node.type = :float
    assert_equal :float, node.type
  end
end
