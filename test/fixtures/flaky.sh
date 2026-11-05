# Passes on runs 1 and 3, fails on run 2: a counter file outlives each run's subshell.
ask() { n=$(cat "$COUNTER" 2>/dev/null || echo 0); n=$((n + 1)); echo $n >"$COUNTER"; [ $((n % 2)) -eq 1 ] && echo yes || echo no; }

test_case "mostly yes" "q"
  equals "yes"
