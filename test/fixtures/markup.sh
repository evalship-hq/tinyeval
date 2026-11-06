# Characters that XML and a Markdown table cell escape.
ask() { echo 'a & b <c> "d" | e'; }

test_case 'x & <y> "z" | w' "q"
  contains "nope"
