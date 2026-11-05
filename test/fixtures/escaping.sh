ask() { printf 'back\\slash "quoted"\ttab\nline two \033[31mred\033[0m'; }

test_case "escaping \"quotes\"" "in"
  contains "line two"
