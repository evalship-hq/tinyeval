# A support bot: reads a customer question on stdin and prints the reply. Needs the anthropic gem.
require "anthropic"

message = Anthropic::Client.new.messages.create(
  model: :"claude-haiku-5-5",
  max_tokens: 16000,
  system_: [{ type: "text", text: File.read(File.join(__dir__, "support-prompt.md")) }],
  messages: [{ role: "user", content: $stdin.read }]
)
puts message.content.select { _1.type == :text }.map(&:text).join
