import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Each test runs a worker in its own process, since the helper moves that process's stdout.
APP = """
from tinyeval import worker, CouldntRun
import os, sys, types
print("app loaded")

# SDK errors as the anthropic and openai packages name them, without either installed.
APIStatusError = type("APIStatusError", (Exception,), {"__module__": "anthropic._exceptions"})
class RateLimitError(APIStatusError): status_code = 429
class BadRequestError(APIStatusError): status_code = 400
APIConnectionError = type("APIConnectionError", (Exception,), {"__module__": "openai._exceptions"})
class APITimeoutError(APIConnectionError): pass

def answer(text):
    print("app called")
    os.system("echo child process")
    if text == "crash": raise RuntimeError("boom")
    if text == "no key": raise CouldntRun("ANTHROPIC_API_KEY\\nisn't set")
    if text == "429": raise RateLimitError("Too many requests")
    if text == "400": raise BadRequestError("model: not found")
    if text == "timeout": raise APITimeoutError("Request timed out")
    return "You said: " + text
"""


def run(stdin=b"", chunks=None, main="worker(answer)"):
    code = APP
    if chunks is not None:  # stdin that hands the worker exactly these reads
        code += f"chunks = {chunks!r}\nsys.stdin = types.SimpleNamespace(buffer=types.SimpleNamespace(read1=lambda n: chunks.pop(0) if chunks else b''))\n"
    p = subprocess.run([sys.executable, "-c", code + main], input=stdin, capture_output=True, cwd=ROOT, timeout=30)
    return p.returncode, p.stdout, p.stderr.decode()


class WorkerTest(unittest.TestCase):
    def test_several_inputs_in_one_read(self):
        code, out, _ = run(b"hi\0\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e \xe2\x9c\x93\0")
        self.assertEqual(out.decode(), "You said: hi\0You said: 日本語 ✓\0")
        self.assertEqual(code, 0)

    def test_an_input_split_across_reads(self):
        _, out, _ = run(chunks=[b"na\xc3", b"\xafve\0sec", b"ond\0"])
        self.assertEqual(out.decode(), "You said: naïve\0You said: second\0")

    def test_the_apps_output_goes_to_stderr(self):
        _, out, err = run(b"hi\0")
        self.assertEqual(out, b"You said: hi\0")
        for line in ("app loaded", "app called", "child process"):
            self.assertIn(line, err)

    def test_couldnt_run(self):
        _, out, _ = run(b"no key\0")
        self.assertEqual(out, b"#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n\0")

    def test_sdk_errors_that_arent_the_apps_fault(self):
        _, out, _ = run(b"429\0timeout\0")
        self.assertEqual(out, b"#tinyeval couldnt_run anthropic: 429 RateLimitError\n\0#tinyeval couldnt_run openai: APITimeoutError\n\0")

    def test_other_errors_become_the_reply_and_the_worker_keeps_going(self):
        _, out, err = run(b"crash\x00400\x00hi\x00")
        self.assertEqual(out, b"RuntimeError: boom\0BadRequestError: model: not found\0You said: hi\0")
        self.assertIn("Traceback", err)

    def test_nul_bytes_are_dropped_from_the_reply(self):
        _, out, _ = run(b"x\0", main="worker(lambda text: 'a\\0b')")
        self.assertEqual(out, b"ab\0")

    def test_an_async_function(self):
        main = "async def reply(text):\n    return answer(text)\nworker(reply)"
        _, out, _ = run(b"hi\0crash\0", main=main)
        self.assertEqual(out, b"You said: hi\0RuntimeError: boom\0")

    def test_the_command_keeps_the_real_stdout(self):
        code = "import sys, tinyeval.__main__; print('tinyeval._worker' in sys.modules)"
        out = subprocess.run([sys.executable, "-c", code], capture_output=True, cwd=ROOT, text=True).stdout
        self.assertEqual(out, "False\n")


if __name__ == "__main__":
    unittest.main()
