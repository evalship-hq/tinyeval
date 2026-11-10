# tinyeval

Test your Java, Kotlin or Scala app's AI replies on every pull request. The test cases sit in a short bash file, and tinyeval runs them against your own JVM code.

## Install

Maven, as a test dependency:

```xml
<dependency>
  <groupId>com.evalship</groupId>
  <artifactId>tinyeval</artifactId>
  <version>0.11.0</version>
  <scope>test</scope>
</dependency>
```

Gradle: `implementation("com.evalship:tinyeval:0.11.0")`. sbt: `libraryDependencies += "com.evalship" % "tinyeval" % "0.11.0"`. Both put it next to your app, so the start script that `installDist` or `stage` writes can run the worker. The jar has no dependencies and runs on Java 8 or later.

## Example

`evals/support.sh` lists the test cases. Its `worker` line starts your worker once, and tinyeval sends it every input:

```bash
worker mvn -q exec:java -Dexec.mainClass=com.example.EvalWorker -Dexec.classpathScope=test

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`src/test/java/com/example/EvalWorker.java` answers each input with your app:

```java
package com.example;

import com.evalship.tinyeval.CouldntRun;
import com.evalship.tinyeval.Tinyeval;

public final class EvalWorker {
    private static Support support;

    public static void main(String[] args) {
        Tinyeval.worker(input -> {
            if (System.getenv("ANTHROPIC_API_KEY") == null) throw new CouldntRun("ANTHROPIC_API_KEY isn't set");
            if (support == null) support = new Support(); // built on the first input
            return support.answer(input);
        });
    }
}
```

In Kotlin it's `Tinyeval.worker { input -> support.answer(input) }` with `val support by lazy { Support() }`, and in Scala `Tinyeval.worker(input => support.answer(input))` with a `lazy val`.

`Tinyeval.worker` points `System.out` at stderr, so what your app prints can't mix into the replies. Build your app inside the lambda, as above: anything printed before the worker starts lands in a reply. The JVM can't move the stdout file itself, so a child process that inherits it, native code, or a logger set up before the worker still writes to the real stdout.

## Errors

- **`throw new CouldntRun("reason")`** marks the test case as couldn't run. tinyeval counts it apart from the failures, and still exits 1.
- **Exceptions from the official Anthropic and OpenAI Java SDKs** count as couldn't run when your code isn't the cause: status 401, 408, 429 or 500 and up, network errors and timeouts, also when wrapped in another exception. The helper finds them by class name, so it depends on neither SDK.
- **Any other exception** becomes the reply, such as `IllegalStateException: no order id`, so the eval fails. The stack trace goes to stderr.

## Run it

Maven compiles the worker and runs tinyeval in one go:

```sh
mvn -q test-compile exec:java -Dexec.mainClass=com.evalship.tinyeval.Main -Dexec.classpathScope=test
```

Add `-Dexec.args="-n 3"` to run each test case three times.

Gradle, with a task in `build.gradle.kts`:

```kotlin
tasks.register<JavaExec>("tinyeval") {
    classpath = sourceSets["main"].runtimeClasspath
    mainClass = "com.evalship.tinyeval.Main"
    standardInput = System.`in`
}
```

```sh
./gradlew -q installDist tinyeval --args="-n 3"
```

Gradle exits 1 for any exit code tinyeval gives other than 0.

sbt 2 runs it in its own JVM. On sbt 1, set `run / fork := true` first.

```sh
sbt stage "runMain com.evalship.tinyeval.Main -n 3"
```

Anywhere else: `java -jar tinyeval-0.11.0.jar`.

## Needs bash

tinyeval is a bash script inside the jar. It needs bash 3.2 or later: macOS and Linux have it, and on Windows it uses [Git for Windows](https://gitforwindows.org)' bash.

## Updating

Change the version in your build file, or let a bot do it: Dependabot and Renovate read `pom.xml` and Gradle builds, and Renovate and Scala Steward read `build.sbt`. With Maven:

```sh
mvn versions:use-latest-releases -Dincludes=com.evalship:tinyeval
```

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge and the options
- Example repos with evals in CI: [java-llm-evals](https://github.com/evalship-hq/java-llm-evals), [kotlin-llm-evals](https://github.com/evalship-hq/kotlin-llm-evals) and [scala-llm-evals](https://github.com/evalship-hq/scala-llm-evals)
