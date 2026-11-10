defmodule Mix.Tasks.Tinyeval do
  @shortdoc "Runs your evals with tinyeval"
  @moduledoc """
  Runs the tinyeval that came with this package, with your arguments: `mix tinyeval -n 3`.

  It compiles your project first, so the workers' `mix run` has nothing to compile and print.
  `mix tinyeval -h` lists the options. Press Ctrl-C twice to stop it.
  """
  use Mix.Task

  @update "mix deps.update tinyeval"

  # A port's program runs in its own session, so Ctrl-C reaches only mix, and a second Ctrl-C
  # stops mix at once. fd 3 is the port's pipe from mix: when mix stops, it closes, and the
  # subshell stops tinyeval with TERM, which tinyeval handles like Ctrl-C.
  @stop_with_mix ~S|(exec 4>&-; cat <&3 >/dev/null; kill -TERM $$ 2>/dev/null) & exec bash "$0" "$@" 3<&- 4>&-|

  @impl true
  def run(args) do
    Mix.Task.run("compile")
    runner = Application.app_dir(:tinyeval, "priv/tinyeval")

    status =
      case :os.type() do
        {:win32, _} ->
          {_, status} =
            System.cmd(bash(), [runner | args],
              into: IO.binstream(),
              env: [{"TINYEVAL_PACKAGE_UPDATE", @update}]
            )

          status

        _ ->
          # nouse_stdio: bash gets this terminal's stdin, stdout and stderr, so it still sees a terminal.
          port =
            Port.open({:spawn_executable, bash()}, [
              :nouse_stdio,
              :exit_status,
              args: ["-c", @stop_with_mix, runner | args],
              env: [{~c"TINYEVAL_PACKAGE_UPDATE", String.to_charlist(@update)}]
            ])

          receive do
            {^port, {:exit_status, status}} -> status
          end
      end

    if status != 0, do: exit({:shutdown, status})
  end

  # On Windows, Git for Windows' bash comes before a bash on PATH, which may be WSL's.
  defp bash do
    case :os.type() do
      {:win32, _} ->
        git = System.find_executable("git")
        # git.exe is in Git\cmd and bash.exe in Git\bin.
        git_bash = [
          git && Path.expand("../../bin/bash.exe", git),
          "C:/Program Files/Git/bin/bash.exe"
        ]

        Enum.find(git_bash, &(&1 && File.regular?(&1))) || System.find_executable("bash") ||
          no_bash("bash from Git for Windows")

      _ ->
        System.find_executable("bash") || no_bash("bash 3.2 or later")
    end
  end

  defp no_bash(what) do
    Mix.shell().error("tinyeval needs #{what}")
    exit({:shutdown, 2})
  end
end
