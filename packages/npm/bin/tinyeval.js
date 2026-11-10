#!/usr/bin/env node
// The tinyeval command: bash runs the bundled tinyeval. It doesn't load the worker helper, which takes stdout.
import { spawnSync } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { constants as os } from "node:os";
import { basename, delimiter, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

let runner = fileURLToPath(new URL("../tinyeval", import.meta.url));
const args = process.argv.slice(2);
const env = { ...process.env, TINYEVAL_PACKAGE_UPDATE: "npm update tinyeval-cli" };
const usable = (file) => {
  try {
    accessSync(file, constants.X_OK);
    return true;
  } catch {
    return false;
  }
};
const onPath = (name) => (process.env.PATH ?? "").split(delimiter).map((dir) => join(dir, name)).find(usable);

let bash = "bash";
if (process.platform === "win32") {
  // Git for Windows' bash comes before a bash on PATH, which may be WSL's.
  const git = onPath("git.exe");
  const gitBash = git && basename(dirname(git)).toLowerCase() === "cmd" && join(dirname(git), "..", "bin", "bash.exe");
  bash = [gitBash, "C:\\Program Files\\Git\\bin\\bash.exe"].find((file) => file && usable(file)) ?? "bash";
  runner = runner.replaceAll("\\", "/");
} else if (process.execve && onPath("bash")) {
  process.execve(onPath("bash"), ["bash", runner, ...args], env); // Node 22.15 and later: bash replaces this process
}

process.on("SIGINT", () => {}); // Ctrl-C reaches bash too, which stops the run and says so
const run = spawnSync(bash, [runner, ...args], { stdio: "inherit", env });
if (run.error) {
  console.error(`tinyeval needs bash${process.platform === "win32" ? " from Git for Windows: https://gitforwindows.org" : ""}`);
  process.exit(2);
}
process.exit(run.status ?? 128 + os.signals[run.signal]);
