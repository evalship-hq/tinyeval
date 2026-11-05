# Run 1 says yes, run 2's AI call fails, run 3 says no: a counter file outlives each run's subshell.
ask() {
  n=$(cat "$COUNTER" 2>/dev/null || echo 0); n=$((n + 1)); echo $n >"$COUNTER"
  case $n in 1) echo yes ;; 2) echo "429 Too Many Requests" >&2; return 1 ;; *) echo no ;; esac
}

test_case "one run broke" "q"
  equals "yes"
