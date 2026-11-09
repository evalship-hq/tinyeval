# Writes the support-bot repo the skill cases start from: a Flask app with one OpenAI call. Sourced by each
# case's fixture.sh, in the run's empty workspace.
cat > bot.py <<'FILE'
"""Acme's support bot: answers customer messages about orders, shipping and refunds."""
import sys

from openai import OpenAI

from orders import load_orders

SYSTEM_PROMPT = """You are Acme's support assistant. Answer questions about orders, shipping and refunds.
Refunds are possible within 30 days of delivery.
Ask for the order number before you promise a refund or a resend."""


def reply(message: str) -> str:
    client = OpenAI()
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        temperature=0.3,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": message},
        ],
    )
    return response.choices[0].message.content


if __name__ == "__main__":
    print(reply(sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()))
FILE
cat > orders.py <<'FILE'
import json
from pathlib import Path


def load_orders(path: str = "orders.json") -> list[dict]:
    """Reads the orders export, newest first."""
    orders = json.loads(Path(path).read_text())
    return sorted(orders, key=lambda order: order["created_at"], reverse=True)
FILE
cat > app.py <<'FILE'
from flask import Flask, request

from bot import reply

app = Flask(__name__)


@app.post("/support")
def support():
    return {"reply": reply(request.json["message"])}
FILE
cat > requirements.txt <<'FILE'
flask==3.1.2
openai==2.8.0
FILE
cat > README.md <<'FILE'
# Acme support

A Flask app whose `/support` endpoint answers customers with an AI support bot (`bot.py`).

Run it with `OPENAI_API_KEY=... flask --app app run`.
FILE
git init -q
git add -A
git -c user.name=Acme -c user.email=dev@acme.test commit -qm "Support bot"
