// The tinyeval command: bash runs the tinyeval file packed next to this program. It doesn't load the worker
// helper, which takes stdout. .NET can't exec, so it waits for bash and exits with its code.
using System.Diagnostics;

var bash = FindBash();
if (bash == null)
{
    Console.Error.WriteLine(OperatingSystem.IsWindows()
        ? "tinyeval needs bash from Git for Windows: https://gitforwindows.org"
        : "tinyeval needs bash");
    return 2;
}
var start = new ProcessStartInfo(bash);
start.ArgumentList.Add(Path.Combine(AppContext.BaseDirectory, "tinyeval").Replace('\\', '/'));
foreach (var arg in args) start.ArgumentList.Add(arg);
// A global tool runs from a .store folder. A local one, from .config/dotnet-tools.json, runs from the NuGet cache.
// shortcut: a --tool-path install is told -g too; name --tool-path if someone uses one.
start.Environment["TINYEVAL_PACKAGE_UPDATE"] = AppContext.BaseDirectory.Contains(".store")
    ? "dotnet tool update -g Tinyeval.Tool, and dotnet add <worker project> package Tinyeval"
    : "dotnet tool update Tinyeval.Tool, and dotnet add <worker project> package Tinyeval";

Console.CancelKeyPress += (_, e) => e.Cancel = true; // Ctrl-C reaches bash too, which stops the run and says so
using var run = Process.Start(start)!;
run.WaitForExit();
return run.ExitCode;

static string? FindBash()
{
    if (!OperatingSystem.IsWindows()) return OnPath("bash");
    // Git for Windows' bash, in Git\bin next to git.exe's Git\cmd, comes before a bash on PATH, which may be WSL's.
    var git = OnPath("git.exe");
    var gitBash = git == null ? null : Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(git))!, "bin", "bash.exe");
    return new[] { gitBash, @"C:\Program Files\Git\bin\bash.exe" }.FirstOrDefault(File.Exists) ?? OnPath("bash.exe");
}

static string? OnPath(string name) =>
    (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator)
        .Where(dir => dir != "").Select(dir => Path.Combine(dir, name)).FirstOrDefault(File.Exists);
