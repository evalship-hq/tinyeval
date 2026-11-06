# tinyeval worker in Elixir. In your eval file:
#   worker elixir evals/worker.exs
# Phoenix or Mix: worker mix run evals/worker.exs starts your app first. Run mix compile
# before tinyeval, as compiling prints to stdout, and keep your app's logs off stdout.

defmodule Worker do
  def reply(input), do: "You said: " <> input # your app's AI call goes here

  # One byte at a time, as a longer read waits until it has every byte it asked for.
  def loop(input) do
    case IO.binread(:stdio, 1) do
      :eof ->
        :ok

      <<0>> ->
        IO.binwrite(:stdio, [reply(IO.iodata_to_binary(input)), 0])
        loop([])

      byte ->
        loop([input, byte])
    end
  end
end

# Raw bytes in and out, as stdio decodes UTF-8 otherwise.
:io.setopts(:standard_io, encoding: :latin1)
Worker.loop([])
