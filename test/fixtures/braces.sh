ask() { cat; }

# On bash 3.2 the apostrophe flips the quotes it sees, so it brace-expanded the rows after it.
test_case "an apostrophe in JSON rows" "$(echo '[{"merchant": "Dunkin'"'"'"},
 {"a": 1, "b": 2}]')"
  equals '[{"merchant": "Dunkin'"'"'"},
 {"a": 1, "b": 2}]'

test_case "braces stay as written" "$(echo {a,b})"
  equals '{a,b}'
