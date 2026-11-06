// tinyeval worker in Kotlin. Build it, then use the jar in your eval file:
//   kotlinc evals/worker.kt -include-runtime -d evals/worker.jar
//   worker java -jar evals/worker.jar
// For your app, build this main into it and run it with your app's classpath, keeping its logs off stdout.
import java.io.ByteArrayOutputStream

fun reply(input: String) = "You said: $input" // your app's AI call goes here

fun main() {
    val stdin = System.`in`.buffered()
    val input = ByteArrayOutputStream()
    while (true) {
        when (val b = stdin.read()) {
            -1 -> return
            0 -> {
                System.out.write(reply(input.toByteArray().decodeToString()).toByteArray())
                System.out.write(0)
                System.out.flush()
                input.reset()
            }
            else -> input.write(b)
        }
    }
}
