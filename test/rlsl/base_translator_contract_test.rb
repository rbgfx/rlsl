# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/base_translator_test_case"

class BaseTranslatorContractTest < Test::Unit::TestCase
  test "generate_shader raises NotImplementedError" do
    translator = ProfileOnlyBaseTranslator.new({}, "", "")
    assert_raise(NotImplementedError) do
      translator.translate
    end
  end

  test "profile raises NotImplementedError when PROFILE is missing" do
    translator = IncompleteBaseTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:profile)
    end
  end
end
