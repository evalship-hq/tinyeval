defmodule TinyevalTest do
  use ExUnit.Case, async: true

  # Runs the worker in its own elixir, as tinyeval does, and writes each chunk to its stdin a moment apart.
  defp worker(chunks) do
    dir = Path.join(System.tmp_dir!(), "tinyeval-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    files =
      for {chunk, i} <- Enum.with_index(chunks) do
        Path.join(dir, "#{i}") |> tap(&File.write!(&1, chunk))
      end

    script = ~S"""
    for f in "${@:3}"; do cat "$f"; sleep 0.2; done |
      elixir -pa "$1" -r "$2" -e 'Tinyeval.worker(&FakeApp.answer/1)' 2>"$0.err"
    """

    ebin = Path.dirname(:code.which(Tinyeval))
    {out, 0} = System.cmd("bash", ["-c", script, dir, ebin, "test/support/fake_app.exs" | files])
    {out, File.read!(dir <> ".err")}
  end

  test "reads several inputs from one chunk, and one input split across chunks" do
    <<a, b>> = "ï"
    {out, _} = worker(["one\0two\0na", <<a>>, <<b, "ve\0">>])
    assert out == "You said: one\0You said: two\0You said: naïve\0"
  end

  test "passes UTF-8 through" do
    {out, _} = worker(["naïve 日本語 ✓\0"])
    assert out == "You said: naïve 日本語 ✓\0"
  end

  test "keeps the app's output off stdout" do
    {out, err} = worker(["hi\0"])
    assert out == "You said: hi\0"
    assert err =~ "app called"
    assert err =~ "app logged"
    assert err =~ "app task"
  end

  test "CouldntRun says couldn't run, on one line, and other errors become the reply" do
    {out, _} = worker(["no key\0429\0after\0"])

    assert out ==
             "#tinyeval couldnt_run anthropic: 401 no key\n\0" <>
               "FakeApp.RateLimitError: rate limited\0You said: after\0"
  end

  test "an app error becomes the reply, with its stack trace on stderr" do
    {out, err} = worker(["crash\0after\0"])
    assert out == "RuntimeError: boom\0You said: after\0"
    assert err =~ "** (RuntimeError) boom"
  end
end
