# Each test case's reply is yes on runs 1 and 3 and no on run 2, so most runs pass and not every one. Run 2 of
# input c couldn't run. A counter file per input outlives each run's subshell.
ask() {
  n=$(cat "$COUNTER.$1" 2>/dev/null || echo 0); n=$((n + 1)); echo $n >"$COUNTER.$1"
  [ "$1$n" != c2 ] || echo "#tinyeval couldnt_run rate limited"
  [ $((n % 2)) -eq 1 ] && echo yes || echo no
}

test_case "most runs" a
  equals "yes"
check every
  every_run
  equals "yes"

test_case "above the checks" b
  every_run
check one
  equals "yes"
check two
  matches "yes|no"

test_case "one run broke" c
  every_run
  equals "yes"
