// tinyeval worker in Java. In your eval file:
//   worker java evals/Worker.java
// Java 11 and later run a source file directly. For your app, add its classpath with -cp, and keep its logs off stdout.
import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class Worker {
    static String reply(String input) {
        return "You said: " + input; // your app's AI call goes here
    }

    public static void main(String[] args) throws IOException {
        var in = new BufferedInputStream(System.in);
        var input = new ByteArrayOutputStream();
        for (int b; (b = in.read()) != -1; ) {
            if (b != 0) {
                input.write(b);
                continue;
            }
            System.out.write(reply(input.toString(StandardCharsets.UTF_8)).getBytes(StandardCharsets.UTF_8));
            System.out.write(0);
            System.out.flush();
            input.reset();
        }
    }
}
