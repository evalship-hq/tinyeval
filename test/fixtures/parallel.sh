ask() { sleep 1; echo "done $1"; }

test_case "one" "1"
  contains "done 1"
test_case "two" "2"
  contains "done 2"
test_case "three" "3"
  contains "done 3"
test_case "four" "4"
  contains "done 4"
