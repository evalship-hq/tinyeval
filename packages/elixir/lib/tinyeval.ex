defmodule Tinyeval do
  @moduledoc """
  A worker for [tinyeval](https://tinyeval.com): your app starts once and answers every test case.

      # evals/worker.exs, started by `worker mix run --no-start evals/worker.exs`
      Tinyeval.worker(fn input -> MyApp.Support.answer(input) end)

  See the README for the rest.
  """

  defmodule CouldntRun do
    @moduledoc """
    Raise it when the AI call couldn't run, such as no key, a 401, a 429, a 5xx or a timeout.
    tinyeval then counts the run apart from the failures instead of grading the reply.
    """
    defexception message: "couldn't run"
  end

  @doc """
  Answers each input tinyeval sends with `answer.(input)`, until tinyeval is done.

  It first points stdout at stderr, so output from your app can't mix with the replies, then
  starts your app when Mix is running. Start the worker with `mix run --no-start`, so your app
  starts after that. `Tinyeval.CouldntRun` marks the run as couldn't run, and any other error
  becomes the reply, so the eval fails.
  """
  @spec worker((String.t() -> String.t())) :: :ok
  def worker(answer) when is_function(answer, 1) do
    out = quiet_stdout()
    # Raw bytes in and out, as stdio decodes UTF-8 otherwise.
    :ok = :io.setopts(out, binary: true, encoding: :latin1)
    if List.keymember?(Application.started_applications(), :mix, 0), do: Mix.Task.run("app.start")
    loop(out, answer, [])
  end

  # One byte at a time, as a longer read waits until it has every byte it asked for.
  defp loop(out, answer, input) do
    case IO.binread(out, 1) do
      :eof ->
        :ok

      <<0>> ->
        IO.binwrite(out, [String.replace(reply(answer, IO.iodata_to_binary(input)), <<0>>, ""), 0])

        loop(out, answer, [])

      byte ->
        loop(out, answer, [input, byte])
    end
  end

  defp reply(answer, input) do
    to_string(answer.(input))
  rescue
    e in CouldntRun ->
      "#tinyeval couldnt_run #{String.replace(Exception.message(e), ~r/\s*\n\s*/, " ")}\n"
  catch
    kind, reason ->
      IO.write(:stderr, Exception.format(kind, reason, __STACKTRACE__))

      case Exception.normalize(kind, reason, __STACKTRACE__) do
        %{__exception__: true} = e -> "#{inspect(e.__struct__)}: #{Exception.message(e)}"
        other -> "#{kind}: #{inspect(other)}"
      end
  end

  # Every process that writes to stdout now writes to stderr: this one, the processes it starts, apps
  # started after this, and Logger. The real stdout stays private, for the replies.
  defp quiet_stdout do
    out = Process.whereis(:user)
    err = Process.whereis(:standard_error)
    relay = spawn(fn -> relay(err) end)
    Process.unregister(:user)
    Process.register(relay, :user)

    for pid <- Process.list(), Process.info(pid, :group_leader) == {:group_leader, out} do
      Process.group_leader(pid, relay)
    end

    out
  end

  defp relay(err) do
    receive do
      msg -> send(err, msg)
    end

    relay(err)
  end
end
