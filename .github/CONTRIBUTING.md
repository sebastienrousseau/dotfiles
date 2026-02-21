<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.487)

A portable shell distribution for macOS, Linux, and WSL.

![Dotfiles banner][banner]

## Contributing

Ways to contribute to Dotfiles.

## Spread the Word

Share Dotfiles with others. A larger community benefits everyone.

## How to Contribute

Guides for submitting issues and pull requests.

### Bug Reports

Found a bug? File a report. Bug reports are high-value contributions.

1. Go to the [issue tracker](https://github.com/sebastienrousseau/dotfiles/issues/new) to submit a new issue.
2. Include a descriptive title that is straight to the point.
3. Write a detailed description of the issue.
4. Wait for a maintainer to triage and label the issue.

### Code Contributions

Code contributions require more involvement but have high impact.

#### Feature Requests

Open a pull request to share your code.

#### Adding Code

1. Fork the repository.
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/dotfiles.git
   ```

#### Fixing an Issue

Found a solution? Submit your fix.

1. Fork the repository and refer above for how to set up the code.
2. Go to your local fork and open a new pull request.
3. Include a title that is straight to the point.
4. Wait for a maintainer to review and merge your pull request.

## Pull request guidelines

### Before submitting

1. **Test your changes** - Run `chezmoi apply` and verify everything works
2. **Check for lint errors** - Run shellcheck on shell scripts
3. **Update documentation** - If you add new features, update relevant docs
4. **Follow existing patterns** - Look at how similar features are implemented

### PR title format

Use a clear, descriptive title:
- `feat: add XYZ configuration`
- `fix: resolve issue with ABC`
- `docs: update installation guide`
- `refactor: simplify alias loading`

### PR description

Include:
- **Summary**: What does this PR do?
- **Motivation**: Why is this change needed?
- **Testing**: How did you test the changes?
- **Screenshots**: If applicable (especially for UI changes)

### Review process

1. A maintainer reviews your PR within a few days
2. Address any requested changes
3. Once approved, a maintainer merges your PR

## Development setup

```bash
# Clone the repo
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles

# Create a feature branch
cd ~/.dotfiles
git checkout -b feat/my-feature

# Make changes and test
chezmoi apply

# Commit and push
git add .
git commit -m "feat: add my feature"
git push origin feat/my-feature
```

## Code style

- **Shell scripts**: Follow the Google Shell Style Guide
- **Use shellcheck**: All shell scripts must pass `shellcheck`
- **Use `set -euo pipefail`**: For robust error handling
- **Portable shebangs**: Use `#!/usr/bin/env bash`

## Questions?

Open an issue with the `question` label if you have questions.

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
