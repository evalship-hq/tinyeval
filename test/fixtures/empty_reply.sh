# For -e, which makes no AI call: ask would leave a file behind.
ask() { : >"$ASKED"; echo "Refunds take 30 days."; }

test_case "needs the answer" "How long do refunds take?"
  contains "30 days"

test_case "only forbids" "How long do refunds take?"
  not_contains "refund approved"

test_case "judged" "How long do refunds take?"
  judge "Names how long a refund takes"
check tone
  not_contains "sorry"
