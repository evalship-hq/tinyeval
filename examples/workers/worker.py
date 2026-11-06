# tinyeval worker in Python. In your eval file:
#   worker python3 evals/worker.py
# Django: set DJANGO_SETTINGS_MODULE and call django.setup() before you import your models.
import sys


def reply(input):
    return "You said: " + input  # your app's AI call goes here


rest = b""
while chunk := sys.stdin.buffer.read1():
    *inputs, rest = (rest + chunk).split(b"\0")
    for input in inputs:
        sys.stdout.buffer.write(reply(input.decode()).encode() + b"\0")
        sys.stdout.buffer.flush()
