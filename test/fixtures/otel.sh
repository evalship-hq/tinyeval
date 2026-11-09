# The app's OpenTelemetry SDK reads OTEL_RESOURCE_ATTRIBUTES: this ask prints the tag tinyeval gave its run.
ask() { printf '%s' "$OTEL_RESOURCE_ATTRIBUTES"; }

test_case "tagged" "x"
  contains "evalship.eval="
check again
  contains "service.name=shop,"
test_case "second" "y"
  contains "evalship.eval="
