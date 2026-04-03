# frozen_string_literal: true

require_relative "support/coverage" if ENV["COVERAGE"] == "1"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "test-unit"
require "rlsl"
