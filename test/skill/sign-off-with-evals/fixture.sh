here=$(dirname "${BASH_SOURCE[0]}")
. "$here/../support-bot.sh"
cp "$here/../../../tinyeval" tinyeval
mkdir evals
cat > evals/support.sh <<'FILE'
ask() { python3 bot.py "$1"; }

test_case "refund after the window" "Can I return shoes that arrived 40 days ago?"
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"

test_case "missing package" "My package never showed up."
  judge "Asks for the order number before promising a refund or resend"
FILE
printf 'eval-results.json\n' > .gitignore
git add -A
git -c user.name=Acme -c user.email=dev@acme.test commit -qm "Evals for the support bot"
