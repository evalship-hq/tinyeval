# check: one reply graded as several evals.
ask() { [ "$1" != down ] || { echo "rate limited" >&2; exit 3; }; printf 'plan: 3 steps\nservings: 4'; }

test_case "braise" "recipe"
  contains "plan"
check servings
  contains "servings: 4"
check units
  contains "grams"
test_case "only checks" "recipe"
check coverage
  contains "steps"
check nothing
test_case "down" "down"
  contains "plan"
check servings
  contains "servings"
