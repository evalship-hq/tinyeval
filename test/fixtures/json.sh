ask() { printf '{"category": "%s", "amount": 12.5}\n' "$1"; }

test_case "right category" "transfer"
  json '.category == "transfer"'
  json '.amount > 10'
test_case "wrong category" "food"
  json '.category == "transfer"'
