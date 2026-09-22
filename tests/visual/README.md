# Real terminal visual contracts

The harness starts a private tmux server inside real Kitty on a Linux Xvfb display.
It never attaches to host sessions or reads provider conversations. Fixtures cover
Maui/Berlin, light/dark, widths 80/100/120/160, prefix/zoom/focus state, uppercase
session identity, location, and Nerd/fallback fonts. CPU/time data are fixed;
status formatting, rendering and state changes are real. Output is PNG plus JSON
with dimensions, checksums and captured terminal text.

```sh
tests_root=$(mktemp -d)
bash tests/visual/fetch-fonts.sh "$tests_root/fonts"
mkdir "$tests_root/screenshots"
docker build -f tests/visual/Dockerfile -t dot-visual-contracts:local .
docker run --rm --init --security-opt no-new-privileges \
  --user "$(id -u):$(id -g)" --env HOME=/tmp \
  --mount "type=bind,src=$PWD,dst=/repo,readonly" \
  --mount "type=bind,src=$tests_root/fonts,dst=/usr/local/share/fonts/dot,readonly" \
  --mount "type=bind,src=$tests_root/screenshots,dst=/output" \
  dot-visual-contracts:local
```

Font files are fetched from Nerd Fonts commit `fa7b859994228a9c8759f99c55a8d31ee92a1b5e`
and SHA-256 verified. JetBrains Mono is under OFL; upstream licensing is retained
at <https://github.com/ryanoasis/nerd-fonts/tree/fa7b859994228a9c8759f99c55a8d31ee92a1b5e/patched-fonts/JetBrainsMono>.
No font files are redistributed in this repository. The fallback fixture currently
substitutes four status icons with ASCII; this is not an implemented runtime font
toggle. System theme high-contrast overrides and screenshots from native macOS,
Windows, Ghostty, WezTerm and other terminals remain distinct acceptance gates.
Numeric contrast is independently covered by the existing palette audit.

PNG checksums identify evidence, not cross-host pixel-perfect promises. Review the
images when changing layout; text/config goldens alone cannot prove font geometry.
