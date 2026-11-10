# frozen_string_literal: true

# Leaves stdout alone, so Bundler.require can load it. A worker requires "tinyeval/worker" instead.
module Tinyeval
  # Raise it when the AI call couldn't run, such as without an API key. tinyeval then counts the run apart from
  # the failures, since it says nothing about the reply.
  class CouldntRun < StandardError; end
end
