# frozen_string_literal: true

require "coverage"

module TestCoverage
  module_function

  def project_root
    File.expand_path("../..", __dir__)
  end

  def lib_root
    File.join(project_root, "lib")
  end

  def summarize(result)
    result.filter_map do |path, data|
      next unless path.start_with?(lib_root)

      lines = data.fetch(:lines)
      relevant = lines.count { |line| !line.nil? }
      covered = lines.count { |line| line&.positive? }
      coverage = relevant.zero? ? 100.0 : (covered * 100.0 / relevant)

      {
        path: path.delete_prefix("#{project_root}/"),
        covered: covered,
        relevant: relevant,
        coverage: coverage
      }
    end
  end
end

Coverage.start(lines: true)

at_exit do
  file_summaries = TestCoverage.summarize(Coverage.result)
  next if file_summaries.empty?

  covered = file_summaries.sum { |file| file[:covered] }
  relevant = file_summaries.sum { |file| file[:relevant] }
  total = relevant.zero? ? 100.0 : (covered * 100.0 / relevant)

  puts
  puts format("Coverage: %.2f%% (%d/%d)", total, covered, relevant)
  puts "Lowest covered files:"

  file_summaries.sort_by { |file| file[:coverage] }.first(5).each do |file|
    puts format("  %6.2f%% %s", file[:coverage], file[:path])
  end

  minimum = ENV.fetch("COVERAGE_MIN", "0").to_f
  abort format("Coverage %.2f%% is below required %.2f%%", total, minimum) if total < minimum
end
