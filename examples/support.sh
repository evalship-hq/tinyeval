# Evals for a support bot written in Ruby. ask is your AI call: it gets the input as $1
# and on stdin, and prints the reply. Swap in python, node, go run, cargo run or curl.
ask() { ruby examples/support.rb; }

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  contains "30 days"
  judge "Says a refund isn't possible anymore, politely"

test_case "missing package" <<'IN'
My package never showed up and I'm getting really annoyed.
IN
  matches "order (number|id|#)"
  judge "Asks for the order number before promising a refund or resend"
