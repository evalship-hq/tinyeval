# The app writes its AI calls to $TINYEVAL_CALLS: two calls, one failing reply, a pretty-printed call, none, and a
# cost the reply says itself.
ask() {
  case $1 in
    two | wrong)
      printf '{"call":"classify","model":"haiku","input":"%s","output":"refund","cost":0.0001}\n' "$1" >>"$TINYEVAL_CALLS"
      printf '{"call":"answer","model":"opus","input":"x \\"quoted\\"","output":"y","cost":2.5e-3,"input_tokens":12}\n' >>"$TINYEVAL_CALLS"
      [ "$1" = two ] && echo "We refund within 30 days." || echo "No refunds." ;;
    pretty) printf '{\n  "call": "answer"\n}\n' >>"$TINYEVAL_CALLS"; echo "30 days" ;;
    said) printf '{"call":"answer","cost":1}\n' >>"$TINYEVAL_CALLS"; printf '#tinyeval cost_usd 0.5\n30 days' ;;
    *) echo "30 days" ;;
  esac
}

test_case "two calls" two
  contains "30 days"
check twice
  contains "refund"
test_case "wrong" wrong
  contains "30 days"
test_case "pretty" pretty
  contains "30 days"
test_case "none" none
  contains "30 days"
test_case "said" said
  contains "30 days"
