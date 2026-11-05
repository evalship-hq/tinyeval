# Test cases that would pass while grading nothing: a misspelled line, and no lines at all.
ask() { echo "hello there"; }

test_case "misspelled" "hi"
  contians "nothing like this"

test_case "no lines" "hi"

test_case "graded" "hi"
  contains "hello"
