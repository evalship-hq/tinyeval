# A long input and reply. bash 3.2 took minutes to escape them one substitution at a time.
ask() { cat; }
long=$(i=0; while [ $i -lt 1000 ]; do printf 'line %s: naïve 日本語 "q" back\\slash\ttab <b>&amp;</b>\n' $i; i=$((i + 1)); done)

test_case "long" "$long"
  contains "line 999:"
test_case "long, and failing" "$long"
  contains "${long:0:3000}x"
