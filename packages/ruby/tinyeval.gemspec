# frozen_string_literal: true

require "fileutils"

# The bash runner and its license, copied from the repo root and kept out of git. Copying here, not in a Rake task,
# also fills them in for Bundler's path: and git: sources.
%w[tinyeval LICENSE].each do |file|
  source = File.expand_path("../../#{file}", __dir__)
  FileUtils.cp(source, File.join(__dir__, file)) if File.exist?(source)
end

Gem::Specification.new do |s|
  s.name = "tinyeval"
  s.version = File.read(File.join(__dir__, "tinyeval"))[/^_te_version=(\S+)$/, 1] # one version, in the runner
  s.summary = "Evals for the AI calls in your Ruby or Rails app, run by one bash file"
  s.description = "tinyeval runs your evals with bundle exec tinyeval. Tinyeval.worker answers them from your app, booted once."
  s.authors = ["evalship"]
  s.homepage = "https://tinyeval.com"
  s.license = "MIT"
  s.required_ruby_version = ">= 3.0"
  s.files = %w[tinyeval LICENSE README.md exe/tinyeval lib/tinyeval.rb lib/tinyeval/worker.rb]
  s.bindir = "exe"
  s.executables = ["tinyeval"]
  s.metadata = {
    "source_code_uri" => "https://github.com/evalship-hq/tinyeval/tree/main/packages/ruby",
    "changelog_uri" => "https://github.com/evalship-hq/tinyeval/releases",
    "bug_tracker_uri" => "https://github.com/evalship-hq/tinyeval/issues",
    "rubygems_mfa_required" => "true"
  }
end
