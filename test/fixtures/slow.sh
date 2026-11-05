# The reply comes from a child process that sleeps past -t.
ask() { sh -c 'sleep 7; echo late'; }

test_case "too slow" "q"
  contains "late"
