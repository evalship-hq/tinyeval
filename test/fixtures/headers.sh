# Lines a reply starts with for tinyeval: the AI call broke, what it cost, and a misspelled one.
ask() {
  case $1 in
    busy) printf '#tinyeval couldnt_run 429 rate limited\n' ;;
    paid) printf '#tinyeval cost_usd 1.25e-05\n{"answer": 42}' ;;
    typo) printf '#tinyeval cost 1\nhello' ;;
  esac
}

test_case "rate limited" busy
  contains "x"
test_case "costs" paid
  json '.answer == 42'
check shape
  json 'has("answer")'
test_case "typo" typo
  contains "hello"
