# tinyeval worker in Ruby. In your eval file:
#   worker ruby evals/worker.rb
# Rails loads your app once per worker with: worker bin/rails runner evals/worker.rb

def reply(input)
  "You said: #{input}" # your app's AI call goes here
end

$stdout.sync = true
while (input = $stdin.gets("\0"))
  print reply(input.chomp("\0")), "\0"
end
