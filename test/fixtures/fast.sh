# 200 test cases whose reply comes at once, from the shell itself.
ask() { echo yes; }

i=1
while [ $i -le 200 ]; do
  test_case "fast $i" "q"
    contains "yes"
  i=$((i + 1))
done
