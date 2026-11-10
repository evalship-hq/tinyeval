#!/usr/bin/env bash
# Builds the gem as RubyGems gets it, installs it into an empty Bundler project, and runs packages/e2e.sh with
# bundle exec tinyeval and a worker on Tinyeval.worker (packages/SPEC.md, Tests).
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gem build --silent tinyeval.gemspec -o "$tmp/tinyeval.gem"
version=$(ruby -rrubygems/package -e 'print Gem::Package.new(ARGV[0]).spec.version' "$tmp/tinyeval.gem")
mkdir -p "$tmp/app/vendor/cache" "$tmp/app/evals"
mv "$tmp/tinyeval.gem" "$tmp/app/vendor/cache/tinyeval-$version.gem"
cp ../e2e.sh "$tmp/app/evals/"
cat >"$tmp/app/evals/worker.rb" <<'RUBY'
require "tinyeval/worker"
puts "app loaded"
Tinyeval.worker do |input|
  puts "app called"
  raise "boom" if input == "crash"
  "You said: #{input}"
end
RUBY

cd "$tmp/app"
printf 'source "https://rubygems.org"\ngem "tinyeval", group: :development\n' >Gemfile
bundle config set --local path vendor/bundle >/dev/null
bundle install --local --quiet

[ "$(bundle exec tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v isn't $version" >&2; exit 1; }
code=0 && out=$(bundle exec tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $out == *"bundle update tinyeval"* ]] || { echo "tinyeval update: exit $code, $out" >&2; exit 1; }
E2E_WORKER="ruby evals/worker.rb" bundle exec tinyeval
