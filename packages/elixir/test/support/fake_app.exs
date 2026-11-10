# The app the worker tests run: it prints in every way an Elixir app does, and fails in the ways tinyeval tells apart.
defmodule FakeApp do
  require Logger

  # Shaped like an SDK's error. Elixir has no official Anthropic or OpenAI SDK, so it becomes the reply.
  defmodule RateLimitError do
    defexception message: "rate limited", status: 429
  end

  def answer("crash"), do: raise("boom")
  def answer("no key"), do: raise(Tinyeval.CouldntRun, "anthropic: 401\nno key")
  def answer("429"), do: raise(RateLimitError)

  def answer(input) do
    IO.puts("app called")
    Logger.info("app logged")
    Task.await(Task.async(fn -> IO.puts("app task") end))
    "You said: " <> input <> <<0>>
  end
end
