#!/usr/bin/env bash
# Packs Tinyeval and Tinyeval.Tool as nuget.org gets them, installs both into an empty project from a local feed,
# and runs packages/e2e.sh through the tool. The release job pushes the packages it leaves in dist/.
set -euo pipefail
cd "$(dirname "$0")"
version=$(sed -n 's/^_te_version=//p' ../../tinyeval)
rm -rf dist
for project in Tinyeval Tinyeval.Tool; do
  dotnet pack "$project" -c Release -o dist --nologo -v q
  [ -f "dist/$project.$version.nupkg" ] || { echo "dist/ has no $project.$version.nupkg: $(ls dist)" >&2; exit 1; }
done

project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R dist "$project/feed"
cp ../e2e.sh "$project/"
cd "$project"
# Its own package cache and dotnet home, so a package rebuilt at the same version is the one that runs.
here=$(pwd -W 2>/dev/null || pwd) # pwd -W: the Windows path, on Git Bash
export NUGET_PACKAGES=$here/packages DOTNET_CLI_HOME=$here DOTNET_NOLOGO=1
cat >nuget.config <<'XML'
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="feed" />
  </packageSources>
</configuration>
XML
dotnet new tool-manifest >/dev/null
dotnet tool install Tinyeval.Tool --version "$version" >/dev/null
mkdir -p evals/Worker
mv e2e.sh evals/
cat >evals/Worker/Worker.csproj <<XML
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Tinyeval" Version="$version" />
  </ItemGroup>
</Project>
XML
cat >evals/Worker/Program.cs <<'CS'
using Tinyeval;

Worker.Run(App.Answer);

static class App
{
    static App() => Console.WriteLine("app loaded"); // a class loads on first use: here, the first input

    public static string Answer(string input)
    {
        Console.WriteLine("app called");
        return input == "crash" ? throw new InvalidOperationException("boom") : "You said: " + input;
    }
}
CS
dotnet build evals/Worker -c Release -o evals/Worker/out --nologo -v q
E2E_WORKER="dotnet evals/Worker/out/Worker.dll" dotnet tinyeval

[ "$(dotnet tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(dotnet tinyeval -v)" >&2; exit 1; }
code=0; said=$(dotnet tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *"dotnet tool update Tinyeval.Tool"* ]] || { echo "tinyeval update exited $code: $said" >&2; exit 1; }
echo "end to end: ok"
