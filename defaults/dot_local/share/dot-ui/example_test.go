// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Runnable examples — they double as documentation and as tests (`go test`
// compares the printed output with the `// Output:` block).
package main

import (
	"fmt"
	"os"
	"strings"
)

// ExampleLoadPalette shows a DOT_UI_* override taking precedence over the
// signature fallback, and an invalid value falling back.
func ExampleLoadPalette() {
	os.Setenv("DOT_UI_ACCENT", "#1a7f7a")
	os.Setenv("DOT_UI_ERROR", "not-a-colour")
	defer os.Unsetenv("DOT_UI_ACCENT")
	defer os.Unsetenv("DOT_UI_ERROR")

	p := LoadPalette()
	fmt.Println(p.Accent)
	fmt.Println(p.Error == fallback.Error)
	// Output:
	// #1a7f7a
	// true
}

// ExampleNewStyles builds the style set and renders a symbol with it. Under
// `go test` there is no colour profile, so the glyph comes back unstyled.
func ExampleNewStyles() {
	st := NewStyles(LoadPalette())
	fmt.Println(st.Ok.Render("✓"), st.Fail.Render("✗"))
	// Output:
	// ✓ ✗
}

// Example_parseEvent decodes one NDJSON line of the `run` protocol.
func Example_parseEvent() {
	e, ok := parseEvent(`{"t":"step","id":"ghostty","label":"Ghostty","state":"ok","detail":"reloaded"}`)
	fmt.Println(ok, e.T, e.ID, e.State, e.Detail)

	_, ok = parseEvent("   ")
	fmt.Println(ok)
	// Output:
	// true step ghostty ok reloaded
	// false
}

// Example_fuzzyMatch shows the fzf-style subsequence matcher.
func Example_fuzzyMatch() {
	fmt.Println(fuzzyMatch("altai-dark", "adk"))
	fmt.Println(fuzzyMatch("altai-dark", "ALT"))
	fmt.Println(fuzzyMatch("altai-dark", "kdar"))
	fmt.Println(fuzzyMatch("Épinal", "é"))
	// Output:
	// true
	// true
	// false
	// true
}

// Example_parsePickArgs parses the picker's two flags.
func Example_parsePickArgs() {
	h, p := parsePickArgs([]string{"--header", "Pick a theme", "--prompt", "Theme >"})
	fmt.Printf("%q %q\n", h, p)
	// Output:
	// "Pick a theme" "Theme >"
}

// Example_snapshotStep renders a whole event stream as one static frame —
// exactly what `DOT_UI_SNAPSHOT=1 dot-ui run` prints.
func Example_snapshotStep() {
	stream := strings.Join([]string{
		`{"t":"header","title":"dot theme","subtitle":"pulse"}`,
		`{"t":"step","id":"a","label":"Ghostty","state":"ok","detail":"reloaded"}`,
		`{"t":"step","id":"b","label":"tmux","state":"skip","detail":"not running"}`,
		`{"t":"done","elapsed_ms":42,"summary":"reloaded ghostty"}`,
	}, "\n")
	_ = snapshotStep(NewStyles(LoadPalette()), strings.NewReader(stream), os.Stdout)
	// Output:
	//
	//   dot theme  · pulse
	//
	//   ✓  Ghostty  reloaded
	//   ·  tmux     not running
	//
	//   Done in 42ms · reloaded ghostty
}

// Example_runTable renders unit-separated rows as a bordered table.
func Example_runTable() {
	in := "Alias\x1fExpands\nll\x1fls -alFh\ngs\x1fgit status\n"
	_ = runTable(LoadPalette(), strings.NewReader(in), os.Stdout)
	// Output:
	//   ╭───────┬────────────╮
	//   │ Alias │ Expands    │
	//   ├───────┼────────────┤
	//   │ ll    │ ls -alFh   │
	//   │ gs    │ git status │
	//   ╰───────┴────────────╯
}
