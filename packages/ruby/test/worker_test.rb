# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"

# Runs a worker in its own ruby process, as tinyeval does, around a fake app with SDK-shaped errors.
class WorkerTest < Minitest::Test
  APP = <<~'RUBY'
    require "tinyeval/worker"
    module Anthropic
      module Errors
        class APIError < StandardError
          attr_reader :status
          def initialize(status)
            @status = status
            super("status #{status}")
          end
        end
        class APIConnectionError < APIError; end
        class APIStatusError < APIError; end
        class RateLimitError < APIStatusError; end
        class BadRequestError < APIStatusError; end
      end
    end
    puts "app loaded"
    system("echo child output")
    Tinyeval.worker do |input|
      puts "app called"
      case input
      when "crash" then raise "boom"
      when "no key" then raise Tinyeval::CouldntRun, "ANTHROPIC_API_KEY isn't\nset"
      when "429" then raise Anthropic::Errors::RateLimitError, 429
      when "400" then raise Anthropic::Errors::BadRequestError, 400
      when "offline" then raise Anthropic::Errors::APIConnectionError, nil
      when "nul" then "a\0b"
      when "invalid" then "a\xFFb"
      else "You said: #{input} (#{input.length} chars)"
      end
    end
  RUBY

  def run_worker(*chunks)
    lib = File.expand_path("../lib", __dir__)
    Open3.popen3(RbConfig.ruby, "-I", lib, "-e", APP) do |stdin, stdout, stderr, thread|
      err = Thread.new { stderr.read }
      chunks.each do |chunk|
        stdin.write(chunk.b)
        stdin.flush
        sleep 0.05
      end
      stdin.close
      out = stdout.read.b
      [out.split("\0", -1).map { |reply| reply.force_encoding(Encoding::UTF_8) }, err.value, thread.value]
    end
  end

  def test_several_inputs_in_one_chunk
    replies, _, status = run_worker("one\0two\0three\0")
    assert_equal ["You said: one (3 chars)", "You said: two (3 chars)", "You said: three (5 chars)", ""], replies
    assert status.success?
  end

  def test_an_input_split_across_chunks_inside_a_character
    bytes = "naïve 日本語 ✓\0".b
    replies, = run_worker(bytes[0, 8], bytes[8, 3], bytes[11..])
    assert_equal ["You said: naïve 日本語 ✓ (11 chars)", ""], replies
  end

  def test_app_output_stays_off_stdout
    replies, err, = run_worker("hi\0")
    assert_equal ["You said: hi (2 chars)", ""], replies
    assert_match(/app loaded\r?\nchild output\r?\napp called\r?\n/, err) # cmd.exe echo ends lines with CRLF
  end

  def test_couldnt_run
    replies, = run_worker("no key\0", "429\0", "offline\0")
    assert_equal [
      "#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n",
      "#tinyeval couldnt_run anthropic: 429 RateLimitError\n",
      "#tinyeval couldnt_run anthropic: APIConnectionError\n",
      ""
    ], replies
  end

  def test_other_errors_become_the_reply_and_the_worker_goes_on
    replies, err, status = run_worker("crash\0", "400\0", "after\0")
    assert_equal ["RuntimeError: boom", "Anthropic::Errors::BadRequestError: status 400", "You said: after (5 chars)", ""],
                 replies
    assert_match(/boom \(RuntimeError\)\n\tfrom .*worker\.rb/, err) # with its stack trace
    assert status.success?
  end

  def test_nul_bytes_are_dropped_from_the_reply_and_bytes_go_as_they_are
    replies, = run_worker("nul\0invalid\0")
    assert_equal ["ab", "a\xFFb", ""], replies
  end
end
