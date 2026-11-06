# problems: the app's own checks return what's wrong with a reply.
ask() { printf '%s' "$1"; }

test_case "none" '{"problems": []}'
  target app/bot.rb#reply src/tags.ts#generateTags
  problems .problems
test_case "two" '{"problems": ["tweet 2 has a hashtag", "quotes $59, not an input price"]}'
  problems .problems
test_case "one as text" '{"problem": "description is empty"}'
  problems .problem
test_case "misspelled field" '{"problems": []}'
  problems .problem
test_case "not JSON" 'Sure! Here are the tags.'
  problems .problems
