ask() { [ "$1" = boom ] && { echo "rate limited" >&2; return 3; }; echo "Sure, refund approved!"; }

test_case "wrong reply" "refund after 40 days"
  contains "30 days"
  judge "Declines the refund"

test_case "ask fails" "boom"
  contains "anything"
