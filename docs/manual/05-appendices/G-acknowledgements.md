---
render_with_liquid: false
---

<!-- Moved from the README (wave 2, R2.3); the text is unchanged. -->

# Appendix G: Acknowledgements

This framework stands on tools whose maintainers did the hard part:
[chezmoi](https://github.com/twpayne/chezmoi) for the source-tree
model that makes every `apply` reproducible, [mise](https://mise.jdx.dev)
and [Nix](https://nixos.org) for toolchains that survive a reinstall,
[age](https://age-encryption.org) and [SOPS](https://github.com/getsops/sops)
for secrets that stay encrypted, and the Charmbracelet libraries
behind the Go satellites. The security posture leans on
[Sigstore](https://www.sigstore.dev), [SLSA](https://slsa.dev),
[OpenSSF Scorecard](https://scorecard.dev), and
[StepSecurity Harden Runner](https://github.com/step-security/harden-runner).

Bug reports with a reproduction and a failing test are the most
useful contribution this project receives; the regression-test
convention in [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) exists so that
every one of them stays fixed.
