# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/base_translator_test_case"

class BaseTranslatorContractTest < Test::Unit::TestCase
  test "generate_shader raises NotImplementedError" do
    translator = IncompleteBaseTranslator.new({}, "", "")
    assert_raise(NotImplementedError) do
      translator.translate
    end
  end

  test "target_vec2_type raises NotImplementedError" do
    translator = IncompleteBaseTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec2_type)
    end
  end

  test "target_vec3_type raises NotImplementedError" do
    translator = IncompleteBaseTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec3_type)
    end
  end

  test "target_vec4_type raises NotImplementedError" do
    translator = IncompleteBaseTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec4_type)
    end
  end
end
