package com.evalship.tinyeval;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The tinyeval command: bash runs the tinyeval bundled in this jar. It doesn't use {@link Tinyeval}, which moves
 * stdout.
 */
public final class Main {
    private Main() {}

    /**
     * Runs tinyeval with these arguments, and exits with its code.
     *
     * @param args tinyeval's arguments, such as {@code -n 3}
     * @throws InterruptedException when interrupted waiting for bash
     */
    public static void main(String[] args) throws InterruptedException {
        boolean windows = System.getProperty("os.name").startsWith("Windows");
        String bash = windows ? gitBash() : "bash";
        if (bash == null) fail("tinyeval needs bash from Git for Windows: https://gitforwindows.org");
        Path runner;
        try {
            runner = write(read());
        } catch (IOException e) {
            fail("couldn't write the bundled tinyeval to a file: " + e);
            return;
        }
        List<String> command = new ArrayList<>(Arrays.asList(bash, windows ? runner.toString().replace('\\', '/') : runner.toString()));
        command.addAll(Arrays.asList(args));
        ProcessBuilder builder = new ProcessBuilder(command).inheritIO();
        builder.environment().put("TINYEVAL_PACKAGE_UPDATE", new File("pom.xml").isFile()
                ? "mvn versions:use-latest-releases -Dincludes=com.evalship:tinyeval"
                : "a newer com.evalship:tinyeval in your build file");
        Process process;
        try {
            process = builder.start();
        } catch (IOException e) {
            fail("couldn't start bash: " + e.getMessage());
            return;
        }
        ignoreCtrlC(); // after the start, as bash would inherit SIGINT ignored
        // A stop ends this JVM: tinyeval's own on Ctrl-C, which signals its process group, or a build tool's. Pass it
        // on to bash and exit with bash's code.
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            process.destroy();
            try {
                Runtime.getRuntime().halt(process.waitFor());
            } catch (InterruptedException e) {
                // the JVM exits with its own code
            }
        }));
        System.exit(process.waitFor());
    }

    static byte[] read() throws IOException {
        try (InputStream in = Main.class.getResourceAsStream("tinyeval")) {
            if (in == null) throw new IOException("no tinyeval in the jar");
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buffer = new byte[65536];
            for (int n; (n = in.read(buffer)) != -1; ) out.write(buffer, 0, n);
            return out.toByteArray();
        }
    }

    // The runner needs a real file, so its $0 works: one per version in the cache folder, or in temp when that's not
    // writable.
    static Path write(byte[] runner) throws IOException {
        Matcher version = Pattern.compile("(?m)^_te_version=(.+)$").matcher(new String(runner, StandardCharsets.UTF_8));
        if (!version.find()) throw new IOException("no _te_version in the bundled tinyeval");
        String cache = System.getenv("XDG_CACHE_HOME");
        Path[] dirs = {
            cache == null || cache.isEmpty() ? Paths.get(System.getProperty("user.home"), ".cache") : Paths.get(cache),
            Paths.get(System.getProperty("java.io.tmpdir")),
        };
        IOException error = null;
        for (Path dir : dirs) {
            Path path = dir.resolve("tinyeval").resolve("tinyeval-" + version.group(1));
            try {
                if (Files.isRegularFile(path) && Arrays.equals(Files.readAllBytes(path), runner)) return path;
                Files.createDirectories(path.getParent());
                // Through a temporary file, so a tinyeval starting at the same time never runs half of it.
                Path tmp = Files.createTempFile(path.getParent(), "tinyeval-", ".tmp");
                Files.write(tmp, runner);
                Files.move(tmp, path, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
                return path;
            } catch (IOException e) {
                error = e;
            }
        }
        throw error;
    }

    // Git for Windows' bash, before a bash on PATH, which may be WSL's.
    static String gitBash() {
        String path = System.getenv("PATH");
        List<File> bashes = new ArrayList<>();
        for (String dir : (path == null ? "" : path).split(File.pathSeparator)) {
            File parent = new File(dir).getParentFile();
            if (new File(dir, "git.exe").isFile() && parent != null) bashes.add(new File(parent, "bin\\bash.exe"));
        }
        bashes.add(new File("C:\\Program Files\\Git\\bin\\bash.exe"));
        for (String dir : (path == null ? "" : path).split(File.pathSeparator)) bashes.add(new File(dir, "bash.exe"));
        for (File bash : bashes) if (bash.isFile()) return bash.getPath();
        return null;
    }

    // Ctrl-C reaches bash too, which stops the run and says so. This JVM waits for it instead of quitting first.
    static void ignoreCtrlC() {
        try {
            Class<?> signal = Class.forName("sun.misc.Signal");
            Class<?> handler = Class.forName("sun.misc.SignalHandler");
            signal.getMethod("handle", signal, handler)
                    .invoke(null, signal.getConstructor(String.class).newInstance("INT"), handler.getField("SIG_IGN").get(null));
        } catch (ReflectiveOperationException | RuntimeException e) {
            // A JVM without sun.misc.Signal quits on Ctrl-C, and bash still prints what it ran.
        }
    }

    private static void fail(String message) {
        System.err.println("tinyeval: " + message);
        System.exit(2);
    }
}
