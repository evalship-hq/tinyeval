# A support bot: reads a customer question on stdin and prints the reply. Ruby's standard library only.
require "json"
require "net/http"

body = { model: "anthropic/claude-haiku-5.5",
         messages: [{ role: "system", content: File.read(File.join(__dir__, "support-prompt.md")) },
                    { role: "user", content: $stdin.read }] }
res = Net::HTTP.post(URI("https://openrouter.ai/api/v1/chat/completions"), body.to_json,
                     "Authorization" => "Bearer #{ENV.fetch("OPENROUTER_API_KEY")}", "Content-Type" => "application/json")
abort "OpenRouter answered #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
puts JSON.parse(res.body).dig("choices", 0, "message", "content")
