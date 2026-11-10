package com.evalship.tinyeval;

import static java.nio.charset.StandardCharsets.UTF_8;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.anthropic.errors.AnthropicIoException;
import com.anthropic.errors.AnthropicServiceException;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.SequenceInputStream;
import java.net.SocketTimeoutException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CompletionException;
import org.junit.jupiter.api.Test;

class TinyevalTest {
    // Each chunk arrives as its own read, as from a pipe.
    static String run(Tinyeval.Answer answer, byte[]... chunks) throws IOException {
        List<InputStream> streams = new ArrayList<>();
        for (byte[] chunk : chunks) streams.add(new ByteArrayInputStream(chunk));
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Tinyeval.serve(new SequenceInputStream(Collections.enumeration(streams)), out, answer);
        return new String(out.toByteArray(), UTF_8);
    }

    static String echo(String input) {
        return "You said: " + input;
    }

    @Test
    void severalInputsInOneChunk() throws IOException {
        assertEquals("You said: a\0You said: b\0", run(TinyevalTest::echo, "a\0b\0".getBytes(UTF_8)));
    }

    @Test
    void anInputSplitInsideAUtf8Character() throws IOException {
        byte[] whole = "naïve 日本語 ✓\0".getBytes(UTF_8); // "ï" is the two bytes C3 AF
        byte[] first = new byte[3], rest = new byte[whole.length - 3];
        System.arraycopy(whole, 0, first, 0, 3);
        System.arraycopy(whole, 3, rest, 0, rest.length);
        assertEquals("You said: naïve 日本語 ✓\0", run(TinyevalTest::echo, first, rest));
    }

    @Test
    void nulBytesAreDroppedFromTheReply() throws IOException {
        assertEquals("xy\0", run(input -> "x\0y", "a\0".getBytes(UTF_8)));
    }

    @Test
    void couldntRunOnOneLine() throws IOException {
        String out = run(input -> {
            throw new CouldntRun("anthropic: 429\nrate limited");
        }, "a\0".getBytes(UTF_8));
        assertEquals("#tinyeval couldnt_run anthropic: 429 rate limited\n\0", out);
    }

    @Test
    void sdkErrorsWithAnOutageStatusCouldntRun() throws IOException {
        String out = run(input -> {
            switch (input) {
                case "429": throw new AnthropicServiceException(429, "rate_limit_error");
                case "joined": throw new CompletionException(new AnthropicServiceException(529, "overloaded"));
                case "timeout": throw new AnthropicIoException("Request failed", new SocketTimeoutException("timeout"));
                default: throw new AnthropicServiceException(400, "max_tokens: too large");
            }
        }, "429\0joined\0timeout\0bad\0".getBytes(UTF_8));
        assertEquals("#tinyeval couldnt_run anthropic: 429 AnthropicServiceException\n\0"
                + "#tinyeval couldnt_run anthropic: 529 AnthropicServiceException\n\0"
                + "#tinyeval couldnt_run anthropic: AnthropicIoException timeout\n\0"
                + "AnthropicServiceException: max_tokens: too large\0", out);
    }

    @Test
    void anAppErrorBecomesTheReplyAndTheWorkerGoesOn() throws IOException {
        String out = run(input -> {
            if (input.equals("crash")) throw new IllegalStateException("boom");
            return echo(input);
        }, "crash\0ok\0".getBytes(UTF_8));
        assertEquals("IllegalStateException: boom\0You said: ok\0", out);
    }

    static boolean loaded;

    // The worker for the test below. Its app loads on the first input, after stdout moved to stderr.
    public static void main(String[] args) {
        Tinyeval.worker(input -> {
            if (!loaded) System.out.println("app loaded");
            loaded = true;
            System.out.println("app called");
            return echo(input);
        });
    }

    @Test
    void theAppsOutputStaysOffStdout() throws Exception {
        String java = System.getProperty("java.home") + File.separator + "bin" + File.separator + "java";
        Process worker = new ProcessBuilder(java, "-cp", System.getProperty("java.class.path"), TinyevalTest.class.getName())
                .redirectError(ProcessBuilder.Redirect.INHERIT)
                .start();
        try (OutputStream stdin = worker.getOutputStream()) {
            stdin.write("a\0b\0".getBytes(UTF_8));
        }
        ByteArrayOutputStream stdout = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        for (int n; (n = worker.getInputStream().read(buffer)) != -1; ) stdout.write(buffer, 0, n);
        assertEquals(0, worker.waitFor());
        assertEquals("You said: a\0You said: b\0", new String(stdout.toByteArray(), UTF_8));
    }

    @Test
    void theVersionIsTinyevalsVersion() throws IOException {
        String version = System.getProperty("tinyeval.version");
        assertTrue(new String(Main.read(), UTF_8).contains("\n_te_version=" + version + "\n"),
                "pom.xml's version " + version + " isn't tinyeval's _te_version: run ./prepare.sh");
    }
}
