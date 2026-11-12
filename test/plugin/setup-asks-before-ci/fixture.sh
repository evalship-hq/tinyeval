here=$(dirname "${BASH_SOURCE[0]}")
. "$here/../support-bot.sh"
cp "$here/../../../tinyeval" tinyeval
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'FILE'
name: CI
on: pull_request
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r requirements.txt
      - run: python -c "import bot"
FILE
git add -A
git -c user.name=Acme -c user.email=dev@acme.test commit -qm "CI and the tinyeval runner"
