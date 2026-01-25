<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.475)

Simply designed to fit your shell life

![Dotfiles banner][banner]

## Contributing to Dotfiles

Thank you so much for wanting to contribute to Dotfiles! There are a
couple ways to help out.

## Evangelize

Just tell people about Dotfiles. We believe that a bigger, more involved
community makes for a better product, and that better products make the
world a better place. We can always use more feedback and learn from you.

## How to Contribute

Please find down here, our guides for submitting issues and pull
requests.

### Bug Reports

If you encounter a bug that hasn't already been filled, please file a
bug report. Let us know of things we should fix, things we should add,
questions, etc.

Warning us of a bug is possibly the single most valuable contribution
you can make to Dotfiles.

* Head [here](https://github.com/sebastienrousseau/dotfiles/issues/new) to submit
  a new issue.
* Include a descriptive title that is straight to the point.
* Write a detailed description on what the issue is all about.
* Wait for someone to get to the issue and add labels.
* The issue will be fixed soon!

### Code Contributions

Contributing code is one of the more difficult ways to contribute to
Dotfiles.

#### Feature Requests

Filling feature requests is one of the most popular ways to contribute
to Dotfiles.

Is there some feature request that you'd like to code up yourself? Is
there a feature you asked for yourself that you'd like to code?

Here's how to contribute code for a new feature to Dotfiles. Pull
requests allow you to share your own code with us, and we can merge it
into the main repo.

#### Adding Code

* Fork the repo.
* Clone the repo **you forked** by running
  `git clone https://github.com/<your-username>/dotfiles.git`

#### Fixing an Issue

Have you found a solution to an issue? Here is how you can submit your
code to Dotfiles.

* Fork the repo, and refer above for how to change up code.
* Head to your local fork of the repo, and click the "New Pull Request"
  button.
* Include a title that is straight to the point.
* Wait for someone to review the pull request, and then merge your pull
  request!

## Pull Request Guidelines

### Before Submitting

1. **Test your changes** - Run `chezmoi apply` and verify everything works
2. **Check for lint errors** - Run shellcheck on shell scripts
3. **Update documentation** - If you add new features, update relevant docs
4. **Follow existing patterns** - Look at how similar features are implemented

### PR Title Format

Use a clear, descriptive title:
- `feat: add XYZ configuration`
- `fix: resolve issue with ABC`
- `docs: update installation guide`
- `refactor: simplify alias loading`

### PR Description

Include:
- **Summary**: What does this PR do?
- **Motivation**: Why is this change needed?
- **Testing**: How did you test the changes?
- **Screenshots**: If applicable (especially for UI changes)

### Review Process

1. A maintainer will review your PR within a few days
2. Address any requested changes
3. Once approved, your PR will be merged

## Development Setup

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

## Code Style

- **Shell scripts**: Follow Google Shell Style Guide
- **Use shellcheck**: All shell scripts should pass shellcheck
- **Use `set -euo pipefail`**: For robust error handling
- **Portable shebangs**: Use `#!/usr/bin/env bash`

## Questions?

Feel free to open an issue with the `question` label if you have any questions.

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
