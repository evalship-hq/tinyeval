"""tinyeval's worker helper. In evals/worker.py, before your app's imports:

    from tinyeval import worker, CouldntRun
"""


class CouldntRun(Exception):
    """Raise it when the AI call couldn't run, such as with no API key, so tinyeval doesn't count a failure."""


def __getattr__(name):
    # Loaded on first use, since loading it moves stdout: the tinyeval command imports this package too.
    if name == "worker":
        from ._worker import worker

        return worker
    raise AttributeError(f"module 'tinyeval' has no attribute {name!r}")
