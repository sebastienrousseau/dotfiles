# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# `dot theme diff`: themes A and B from themes.toml side by side (root, .ui
# and .term keys), a ≠ on each row that differs, 24-bit swatches for colours.
# Run as: awk -v A=<theme> -v B=<theme> -f diff.awk <themes.toml>
BEGIN {
  esc = sprintf("%c[", 27)
  for (side in slot) delete slot[side]
}
function set_slot(name, section, key, value) {
  # `section` is "" for root, "app" or "ui" or "term"
  slot[name "." section "." key] = value
}
function get(name, section, key) {
  return slot[name "." section "." key]
}
function hex2int(h,   n,i,c,d) {
  d="0123456789abcdef"; n=0; h=tolower(h)
  for(i=1;i<=length(h);i++){c=index(d,substr(h,i,1)); if(c==0)return 0; n=n*16+(c-1)}
  return n
}
function swatch(hex,  s,r,g,b) {
  if (hex == "" || hex !~ /^#/) return "    "
  s = substr(hex, 2)
  r = hex2int(substr(s,1,2)); g = hex2int(substr(s,3,2)); b = hex2int(substr(s,5,2))
  return esc "48;2;" r ";" g ";" b "m    " esc "0m"
}
function val(line,   v) { v=line; sub(/^[^=]*= *"?/,"",v); sub(/"?[[:space:]]*$/,"",v); return v }
{
  if ($0 == "[themes." A "]")      { name=A; section=""; next }
  else if ($0 == "[themes." A ".ui]")   { name=A; section="ui"; next }
  else if ($0 == "[themes." A ".term]") { name=A; section="term"; next }
  else if ($0 == "[themes." B "]")      { name=B; section=""; next }
  else if ($0 == "[themes." B ".ui]")   { name=B; section="ui"; next }
  else if ($0 == "[themes." B ".term]") { name=B; section="term"; next }
  else if (/^\[/) { name=""; section=""; next }
}
name != "" && /=/ {
  key = $0; sub(/ *=.*/, "", key)
  set_slot(name, section, key, val($0))
}
function row(label, left, right) {
  mark = (left == right ? " " : "≠")
  printf "  %s  %-14s  %-24s  %-24s\n", mark, label, left, right
}
function row_sw(label, left, right) {
  mark = (left == right ? " " : "≠")
  printf "  %s  %-14s  %s %-18s  %s %-18s\n", mark, label, swatch(left), left, swatch(right), right
}
END {
  row("family",       get(A,"","family"),        get(B,"","family"))
  row("mode",         get(A,"","mode"),          get(B,"","mode"))
  row("macos_accent", get(A,"","macos_accent"),  get(B,"","macos_accent"))
  row("wallpaper",    get(A,"","wallpaper"),     get(B,"","wallpaper"))
  row_sw("ui.accent", get(A,"ui","accent"),      get(B,"ui","accent"))
  row_sw("term.bg",   get(A,"term","bg"),        get(B,"term","bg"))
  row_sw("term.fg",   get(A,"term","fg"),        get(B,"term","fg"))
}
