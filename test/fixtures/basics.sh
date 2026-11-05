# ask echoes a canned reply per input, so every assertion has a known answer.
ask() {
  case $1 in
    refund*) echo "Refunds are possible within 30 days of purchase." ;;
    json) echo '{"total": 3}' ;;
    *) cat ;; # echo stdin back
  esac
}

test_case "contains, ignoring case" "refund?"
  contains "30 DAYS"
  not_contains "never"
  matches "within [0-9]+ days"

test_case "equals" "hello"
  equals "hello"

test_case "expect with a command" "json"
  expect grep -q '"total": 3'

short() { [ "$(wc -c)" -lt 10 ] || { echo "too long"; return 1; }; }
test_case "expect with a function" "hello"
  expect short

test_case "heredoc input" <<'IN'
line one
line two
IN
  contains "line two"

test_case "judge passes" "refund"
  judge "Mentions a time window"
