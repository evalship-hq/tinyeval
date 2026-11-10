package com.evalship.tinyeval;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

/**
 * A worker for <a href="https://tinyeval.com">tinyeval</a>: it answers each test case's input with your code.
 *
 * <pre>{@code
 * public static void main(String[] args) {
 *     Tinyeval.worker(input -> "You said: " + input);
 * }
 * }</pre>
 */
public final class Tinyeval {
    private Tinyeval() {}

    /** Your code's reply to one input. */
    @FunctionalInterface
    public interface Answer {
        /**
         * Returns the reply to one input.
         *
         * @param input the test case's input
         * @return the reply tinyeval checks
         * @throws Exception {@link CouldntRun} when the AI call couldn't run, or any error, which becomes the reply
         */
        String answer(String input) throws Exception;
    }

    /**
     * Answers each input tinyeval sends with {@code answer}, until tinyeval closes stdin, then exits 0.
     *
     * <p>It first points {@code System.out} at stderr and keeps the real stdout for the replies, so build your app
     * after it starts: on the first call, or in a lazy value. The JVM can't move the stdout file itself, so child
     * processes that inherit it, native code, {@code FileDescriptor.out} and a logger that took {@code System.out}
     * earlier still write to the real stdout.
     *
     * <p>Throw {@link CouldntRun} when the AI call couldn't run. Exceptions from the official Anthropic and OpenAI
     * Java SDKs count too when your app isn't the cause: status 401, 408, 429 or 500 and up, network errors and
     * timeouts. Any other exception becomes the reply, as {@code ExceptionName: message}, so the eval fails.
     *
     * @param answer your code, called with each input
     */
    public static void worker(Answer answer) {
        System.out.flush();
        OutputStream replies = new FileOutputStream(FileDescriptor.out);
        System.setOut(System.err);
        try {
            serve(System.in, replies, answer);
        } catch (IOException e) {
            e.printStackTrace(); // tinyeval stopped reading
            System.exit(1);
        }
        System.exit(0); // an HTTP client's threads would keep the JVM up
    }

    static void serve(InputStream stdin, OutputStream replies, Answer answer) throws IOException {
        InputStream in = new BufferedInputStream(stdin);
        ByteArrayOutputStream input = new ByteArrayOutputStream();
        for (int b; (b = in.read()) != -1; ) {
            if (b != 0) {
                input.write(b);
                continue;
            }
            // Decoded once whole, so a character split across reads survives.
            String reply = reply(answer, new String(input.toByteArray(), StandardCharsets.UTF_8));
            input.reset();
            replies.write((reply.replace("\0", "") + "\0").getBytes(StandardCharsets.UTF_8));
            replies.flush();
        }
    }

    static String reply(Answer answer, String input) {
        try {
            return String.valueOf(answer.answer(input));
        } catch (Throwable e) { // Kotlin's TODO() throws an Error
            String reason = couldntRun(e);
            if (reason == null) {
                e.printStackTrace();
                return e.getClass().getSimpleName() + (e.getMessage() == null ? "" : ": " + e.getMessage());
            }
            String line = reason.trim().replaceAll("\\s+", " ");
            return "#tinyeval couldnt_run " + (line.isEmpty() ? "CouldntRun" : line) + "\n";
        }
    }

    // Why the call couldn't run, or null when the error is the reply. It looks through the causes, as join() and
    // app code wrap errors. The SDKs' classes are known by name, so neither SDK has to be on the classpath.
    static String couldntRun(Throwable e) {
        for (int depth = 0; e != null && depth < 20; e = e.getCause(), depth++) {
            if (e instanceof CouldntRun) return e.getMessage() == null ? "" : e.getMessage();
            for (Class<?> c = e.getClass(); c != null; c = c.getSuperclass()) {
                String name = c.getName();
                String sdk = name.startsWith("com.anthropic.errors.") ? "anthropic"
                        : name.startsWith("com.openai.errors.") ? "openai" : null;
                if (sdk == null) continue;
                String type = e.getClass().getSimpleName();
                if (name.endsWith("IoException") || name.endsWith("RetryableException")) { // the network or a timeout
                    return sdk + ": " + type + (e.getCause() == null ? "" : " " + e.getCause().getMessage());
                }
                if (name.endsWith("ServiceException")) {
                    int status;
                    try {
                        status = ((Number) c.getMethod("statusCode").invoke(e)).intValue();
                    } catch (ReflectiveOperationException | RuntimeException unknown) {
                        return null;
                    }
                    return status == 401 || status == 408 || status == 429 || status >= 500
                            ? sdk + ": " + status + " " + type
                            : null;
                }
            }
        }
        return null;
    }
}
