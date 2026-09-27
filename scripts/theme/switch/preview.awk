# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# fzf preview for `dot theme`: the theme F-M from themes.toml (the file
# argument) as family, wallpaper, accent, bg/fg and the 16-colour palette,
# with 24-bit swatches. Run as: awk -v F=<family> -v M=<mode> -f preview.awk <themes.toml>
# Portable awk only (macOS one-true-awk, mawk, busybox): no gawk extensions.
BEGIN {
  root = "[themes." F "-" M "]"
  ui   = "[themes." F "-" M ".ui]"
  term = "[themes." F "-" M ".term]"
  esc  = sprintf("%c[", 27)
}
function hex2int(h,   n, i, c, digits) {
  digits = "0123456789abcdef"
  n = 0
  h = tolower(h)
  for (i = 1; i <= length(h); i++) {
    c = index(digits, substr(h, i, 1))
    if (c == 0) return 0
    n = n * 16 + (c - 1)
  }
  return n
}
function swatch(hex,   clean, r, g, b) {
  clean = hex
  sub(/^#/, "", clean)
  r = hex2int(substr(clean, 1, 2))
  g = hex2int(substr(clean, 3, 2))
  b = hex2int(substr(clean, 5, 2))
  return esc "48;2;" r ";" g ";" b "m    " esc "0m"
}
$0 == root { in_root=1; in_ui=0; in_term=0; next }
$0 == ui   { in_ui=1; in_root=0; in_term=0; next }
$0 == term { in_term=1; in_root=0; in_ui=0; next }
/^\[/ { in_root=0; in_ui=0; in_term=0; next }
in_root && /^wallpaper /   { sub(/.*= *"?/,""); sub(/"$/,""); wallpaper=$0 }
in_root && /^macos_accent/ { sub(/.*= */,"");   accent_int=$0 }
in_ui && /^accent /        { sub(/.*= *"?/,""); sub(/"$/,""); accent=$0 }
in_term && /^bg /          { sub(/.*= *"?/,""); sub(/"$/,""); bg=$0 }
in_term && /^fg /          { sub(/.*= *"?/,""); sub(/"$/,""); fg=$0 }
in_term && /^c[0-9]+ *= *"/ {
    # Not match($0, re, m): the three-argument form is a gawk extension,
    # and macOS ships the one-true-awk, which rejects it outright — the
    # whole preview then dies with a syntax error.
    _k = $0; sub(/ *=.*$/, "", _k); sub(/^c/, "", _k)
    _v = $0; sub(/^[^"]*"/, "", _v); sub(/".*$/, "", _v)
    term_c[_k+0] = _v
  }
END {
  print "family:    " F " (" M ")"
  print "wallpaper: " wallpaper
  print "accent:    " swatch(accent) " " accent " (macos=" accent_int ")"
  print "bg:        " swatch(bg) " " bg
  print "fg:        " swatch(fg) " " fg
  print ""
  # 16-colour ANSI palette, laid out 8 wide × 2 rows.
  line1 = ""; line2 = ""
  for (i = 0; i <= 7; i++)  line1 = line1 swatch(term_c[i])
  for (i = 8; i <= 15; i++) line2 = line2 swatch(term_c[i])
  print "palette:"
  print "  " line1
  print "  " line2
}
