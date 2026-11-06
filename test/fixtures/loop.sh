# A loop that reads each input into a variable named input, as an eval file may.
ask() { printf 'reply to %s' "$1"; }

while IFS= read -r input; do
  test_case "$input" "$input"
    contains "reply to $input"
done <<'IN'
first
second
IN
