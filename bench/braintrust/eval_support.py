# examples/support.sh in Braintrust: the same AI call (examples/support.rb) and the same judge model.
import re
import subprocess

from autoevals import LLMClassifier
from braintrust import Eval


def ask(input):
    return subprocess.run(["ruby", "../../examples/support.rb"], input=input, capture_output=True, text=True, check=True).stdout


def rules(output, metadata, **kwargs):
    contains = all(t.lower() in output.lower() for t in metadata.get("contains", []))
    matches = all(re.search(r, output) for r in metadata.get("matches", []))
    return 1 if contains and matches else 0


judge = LLMClassifier(
    name="judge",
    prompt_template="Reply:\n{{output}}\n\nDoes the reply meet this criterion? {{metadata.criterion}}",
    choice_scores={"Y": 1, "N": 0},
    model="claude-haiku-5-5",
    use_cot=True,
)

Eval(
    "support",
    data=lambda: [
        {"input": "Can I still return my shoes? They arrived 40 days ago.",
         "metadata": {"matches": ["30[- ]day"], "criterion": "Says a refund isn't possible anymore, politely"}},
        {"input": "My package never showed up and I'm getting really annoyed.",
         "metadata": {"matches": ["order (number|id|#)"], "criterion": "Asks for the order number before promising a refund or resend"}},
    ],
    task=ask,
    scores=[rules, judge],
    trial_count=3,
    max_concurrency=4,
)
