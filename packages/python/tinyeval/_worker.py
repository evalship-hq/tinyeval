import inspect
import os
import sys
import traceback

from . import CouldntRun

# The app's output goes to stderr, from Python and from child processes alike. Replies go to the real stdout.
sys.stdout.flush()
_replies = os.fdopen(os.dup(1), "wb")
os.dup2(2, 1)
sys.stdout = sys.stderr
_loop = None  # one event loop for the worker's life, so an async client keeps its connections


def _sdk_error(e):
    """'anthropic: 429 RateLimitError' for an SDK error that isn't the app's fault, found without importing the SDK."""
    for cls in type(e).__mro__:
        sdk = cls.__module__.split(".")[0]
        if sdk not in ("anthropic", "openai"):
            continue
        if cls.__name__ == "APIConnectionError":  # APITimeoutError is one too
            return f"{sdk}: {type(e).__name__}"
        status = getattr(e, "status_code", None)
        if cls.__name__ == "APIStatusError" and isinstance(status, int) and (status in (401, 429) or status >= 500):
            return f"{sdk}: {status} {type(e).__name__}"
    return None


def _reply(answer, data):
    global _loop
    try:
        reply = answer(data.decode())
        if inspect.isawaitable(reply):
            import asyncio

            _loop = _loop or asyncio.new_event_loop()
            reply = _loop.run_until_complete(reply)
        return str(reply)
    except Exception as e:
        reason = str(e) if isinstance(e, CouldntRun) else _sdk_error(e)
        if reason is not None:
            return "#tinyeval couldnt_run " + (" ".join(reason.split()) or "CouldntRun") + "\n"
        traceback.print_exc()
        return f"{type(e).__name__}: {e}"


def worker(answer):
    """Calls answer with each input tinyeval sends, and sends back what it returns."""
    rest = b""
    while True:
        chunk = sys.stdin.buffer.read1(65536)
        if not chunk:
            return
        *inputs, rest = (rest + chunk).split(b"\0")
        for data in inputs:
            _replies.write(_reply(answer, data).replace("\0", "").encode("utf-8", "replace") + b"\0")
            _replies.flush()
