# The worker starts once and numbers its calls, so the third test case shows it kept running.
worker bash -c 'n=0; while IFS= read -r -d "" q; do n=$((n + 1)); printf "%s, call %s\0" "$q" "$n"; done'

test_case "first" "hello"
  contains "hello, call 1"
test_case "multi-line input" "one
two"
  equals "one
two, call 2"
test_case "third" "again"
  contains "again, call 3"
