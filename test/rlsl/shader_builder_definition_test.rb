# frozen_string_literal: true

require_relative "../test_helper"

class ShaderBuilderFunctionsTest < Test::Unit::TestCase
  test "functions block registers custom functions" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.functions do
      float :helper1
      vec3 :get_color
    end

    custom_funcs = builder.instance_variable_get(:@definition).custom_functions
    assert_equal({ returns: :float }, custom_funcs[:helper1])
    assert_equal({ returns: :vec3 }, custom_funcs[:get_color])
  end

  test "functions block with define" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.functions do
      define :complex_func, returns: :vec3, params: { x: :float }
    end

    custom_funcs = builder.instance_variable_get(:@definition).custom_functions
    expected = { returns: :vec3, params: { x: :float } }
    assert_equal expected, custom_funcs[:complex_func]
  end
end

class ShaderBuilderHelpersModeTest < Test::Unit::TestCase
  test "helpers sets block and mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.helpers(:ruby) { "helper code" }

    definition = builder.instance_variable_get(:@definition)
    assert_not_nil definition.helpers_block
    assert_equal :ruby_source, definition.helpers_mode
  end
end

class ShaderBuilderFragmentModeTest < Test::Unit::TestCase
  test "fragment with no args sets C mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { "C code" }
    assert_equal :c, builder.instance_variable_get(:@definition).fragment_mode
  end

  test "fragment with args sets Ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { |frag_coord| vec3(1.0, 0.0, 0.0) }
    assert_equal :ruby_source, builder.instance_variable_get(:@definition).fragment_mode
  end

  test "fragment with multiple args sets Ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }
    assert_equal :ruby_source, builder.instance_variable_get(:@definition).fragment_mode
  end
end
