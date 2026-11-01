---
name: Bug report
about: Create a report to help us improve
title: ''
labels: 'type:bug'
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:

1. Run `dot ...`
2. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment**

- OS and version (e.g., macOS 14.2, Ubuntu 24.04, WSL2):
- Shell (`echo $SHELL`):
- Dotfiles version (`dot --version`):
- Output of `dot doctor` (if available):

**Logs**
Include relevant lines from the dot CLI's logs, `${XDG_STATE_HOME:-~/.local/state}/dot/<domain>/log.jsonl` (`dot-audit` shows the latest), if applicable. They hold command names, counts and ids, never file contents.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Additional context**
Add any other context about the problem here.
