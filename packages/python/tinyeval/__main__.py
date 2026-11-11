"""The tinyeval command: runs the bundled tinyeval with bash."""

import os
import shutil
import signal
import subprocess
import sys
from pathlib import Path


def _bash():
    if os.name == "nt":  # Git for Windows' bash before one on PATH, which may be WSL's
        git = shutil.which("git")  # Git\cmd\git.exe, with bash in Git\bin
        found = [Path(git).parent.parent / "bin" / "bash.exe"] if git else []
        for bash in found + [Path(r"C:\Program Files\Git\bin\bash.exe")]:
            if bash.is_file():
                return str(bash)
    return shutil.which("bash")


def main():
    bash = _bash()
    if not bash:
        print("tinyeval needs bash. On Windows, install Git for Windows: https://gitforwindows.org", file=sys.stderr)
        sys.exit(2)
    args = [bash, Path(__file__).with_name("tinyeval").as_posix(), *sys.argv[1:]]
    # tinyeval runs from the repo root, where a uv project keeps uv.lock.
    update = "uv lock --upgrade-package tinyeval-cli" if Path("uv.lock").is_file() else "pip install -U tinyeval-cli"
    env = dict(os.environ, TINYEVAL_PACKAGE_UPDATE=update)
    if os.name != "nt":
        os.execve(bash, args, env)
    signal.signal(signal.SIGINT, signal.SIG_IGN)  # bash gets Ctrl-C, stops its jobs and exits with its code
    sys.exit(subprocess.run(args, env=env).returncode)


if __name__ == "__main__":
    main()
