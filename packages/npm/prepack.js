// Copies the repo's tinyeval in, and gives package.json its _te_version, so a release changes one line.
import { copyFileSync, readFileSync, writeFileSync } from "node:fs";

copyFileSync("../../tinyeval", "tinyeval");
copyFileSync("../../LICENSE", "LICENSE");
const version = readFileSync("tinyeval", "utf8").match(/^_te_version=(.+)$/m)[1];
const pkg = JSON.parse(readFileSync("package.json", "utf8"));
if (pkg.version !== version) writeFileSync("package.json", JSON.stringify({ ...pkg, version }, null, 2) + "\n");
