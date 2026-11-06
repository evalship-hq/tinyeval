# The worker stops on "crash" and never answers "hang"; the next test case gets a new one each time.
worker bash -c 'while IFS= read -r -d "" q; do
  case $q in crash) echo "out of memory" >&2; exit 1 ;; hang) sleep 30 ;; esac
  printf "ok %s\0" "$q"
done'

test_case "crashes" "crash"
  contains "ok"
test_case "after a crash" "a"
  contains "ok a"
test_case "hangs" "hang"
  contains "ok"
test_case "after a hang" "b"
  contains "ok b"
