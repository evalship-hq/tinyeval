# The end-to-end suite every package runs through its own tinyeval command (packages/SPEC.md, Tests).
# E2E_WORKER starts a worker built on the package's helper, around a fake app that prints to stdout.
worker $E2E_WORKER

test_case "UTF-8 reply, with the app's output kept off stdout" "naïve 日本語 ✓"
  equals "You said: naïve 日本語 ✓"

test_case "an app error becomes the reply" "crash"
  contains "boom"
