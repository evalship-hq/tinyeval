#!/usr/bin/env bash
# Builds the jar as Maven Central gets it, and runs packages/e2e.sh in an empty project with the jar's tinyeval
# command, and a worker on the jar's helper.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
./prepare.sh
version=$(sed -n 's/^_te_version=//p' ../../tinyeval)
mvn -B -q package -DskipTests
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "target/tinyeval-$version.jar" "$tmp/tinyeval.jar"

cd "$tmp" && mkdir evals && cp "$here/../e2e.sh" evals/
cat >Worker.java <<'JAVA'
import com.evalship.tinyeval.Tinyeval;

public class Worker {
    static class App {
        App() {
            System.out.println("app loaded");
        }

        String call(String input) {
            System.out.println("app called");
            if (input.equals("crash")) throw new IllegalStateException("boom");
            return "You said: " + input;
        }
    }

    static App app;

    public static void main(String[] args) {
        Tinyeval.worker(input -> {
            if (app == null) app = new App(); // after stdout moved to stderr
            return app.call(input);
        });
    }
}
JAVA
# Java 11 and later run a source file, so the worker needs no build step.
E2E_WORKER="java -cp tinyeval.jar Worker.java" java -jar tinyeval.jar

said=$(java -jar tinyeval.jar -v)
[ "$said" = "tinyeval $version" ] || { echo "tinyeval -v printed $said" >&2; exit 1; }
for build in build.gradle.kts pom.xml; do # the update command depends on the build file
  touch "$build"
  status=0 && said=$(java -jar tinyeval.jar update 2>&1) || status=$?
  want='a newer com.evalship:tinyeval' && [ "$build" = pom.xml ] && want='mvn versions:use-latest-releases'
  [ "$status" = 2 ] && [[ $said == *"$want"* ]] || { echo "tinyeval update exited $status: $said" >&2; exit 1; }
done
echo "e2e: ok"
