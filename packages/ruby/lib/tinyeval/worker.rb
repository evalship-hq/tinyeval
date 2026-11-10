# frozen_string_literal: true

require_relative "../tinyeval"

# Require this before your app. From here on, all output to stdout goes to stderr, at the file descriptor, so
# puts, child processes and C extensions stay off the replies. The replies go to the real stdout.
module Tinyeval
  REPLIES = STDOUT.dup.binmode
  STDOUT.reopen(STDERR)

  # Answers each input tinyeval sends, up to a NUL byte, with the block's return value and a NUL byte.
  def self.worker
    $stdin.binmode
    while (input = $stdin.gets("\0"))
      break unless input.chomp!("\0") # stdin closed partway through an input
      reply =
        begin
          out = yield(input.force_encoding(Encoding::UTF_8)).to_s
          out.encoding == Encoding::BINARY ? out : out.encode(Encoding::UTF_8) # bytes, as Net::HTTP gives, go as is
        rescue StandardError => e
          if (reason = couldnt_run(e))
            "#tinyeval couldnt_run #{reason.split.join(" ")}\n"
          else
            warn e.full_message
            "#{e.class}: #{e.message}" # the reply, so the eval fails
          end
        end
      REPLIES.write(reply.b.delete("\0"), "\0") # .b: delete raises on invalid UTF-8
      REPLIES.flush
    end
  end

  # Why the AI call couldn't run, or nil when the error is the app's. The anthropic and openai gems' errors are
  # matched by class name, so neither gem has to be installed: 401, 429, 5xx, connection errors and timeouts.
  def self.couldnt_run(error)
    return error.message if error.is_a?(CouldntRun)

    names = error.class.ancestors.map(&:name).compact
    sdk = names.grep(/\A(Anthropic|OpenAI)::Errors::APIError\z/).first or return
    status = error.status if error.respond_to?(:status)
    connection = names.include?("#{sdk[/\A\w+/]}::Errors::APIConnectionError") # timeouts are one too
    return unless connection || [401, 429].include?(status) || status.to_i >= 500

    "#{sdk[/\A\w+/].downcase}: #{[status, error.class.name.to_s[/\w+\z/]].compact.join(" ")}"
  end
end
