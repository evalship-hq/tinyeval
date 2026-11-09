# A worker writes each input's AI call to $TINYEVAL_CALLS, which tinyeval clears between test cases.
worker bash -c 'while IFS= read -r -d "" q; do printf "{\"call\":\"%s\"}\n" "$q" >>"$TINYEVAL_CALLS"; printf "%s\0" "$q"; done'

test_case "first" "one"
  contains "one"
test_case "second" "two"
  contains "two"
