# promptfoo's exec provider passes the prompt as the first argument; support.rb reads stdin.
printf '%s' "$1" | ruby ../../examples/support.rb
