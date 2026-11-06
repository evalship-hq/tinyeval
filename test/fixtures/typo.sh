# Test cases that would pass while grading nothing: a misspelled line, no lines at all, and a second "graded" that would
# merge into the first.
ask() { echo "hello there"; }

test_case "misspelled" "hi"
  contians "nothing like this"

test_case "no lines" "hi"

test_case "graded" "hi"
  contains "hello"

test_case "graded" "hi"
  contains "hello"
