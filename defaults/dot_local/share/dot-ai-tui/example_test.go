// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Runnable examples — they double as documentation and as tests (`go test`
// compares the printed output with the `// Output:` block).
package main

import (
	"fmt"
	"strings"
)

// Example_buildPrompt flattens prior turns into a fresh one-shot prompt so
// the tool keeps the conversation context.
func Example_buildPrompt() {
	history := []line{
		{who: "you", text: "name a colour"},
		{who: "claude", text: "violet"},
		{who: "sys", text: "model → opus"}, // system notes never reach the tool
	}
	fmt.Println(buildPrompt(history, "and a darker one?"))
	// Output:
	// Continue this conversation. Reply only as the assistant, concisely.
	//
	// User: name a colour
	//
	// Assistant: violet
	//
	// User: and a darker one?
	//
	// Assistant:
}

// Example_highlight leaves prose untouched and only touches fenced code.
func Example_highlight() {
	fmt.Println(highlight("plain prose stays exactly as written"))
	fmt.Println(strings.Contains(highlight("```go\nvar x = 1\n```"), "\x1b["))
	// Output:
	// plain prose stays exactly as written
	// true
}

// Example_resolveLang maps a fence info string to a chroma lexer name.
func Example_resolveLang() {
	fmt.Printf("%q %q %q\n", resolveLang("ts"), resolveLang("go"), resolveLang("not a language"))
	// Output:
	// "TypeScript" "Go" ""
}

// Example_windowRows keeps the cursor row visible in a fixed-height list.
func Example_windowRows() {
	rows := []string{"a", "b", "c", "d", "e", "f", "g"}
	fmt.Println(windowRows(rows, 5, 3))
	fmt.Println(windowRows(rows, 0, 3))
	// Output:
	// [e f g]
	// [a b c]
}

// Example_nextModel cycles through the model overrides offered by `m`.
func Example_nextModel() {
	cur := ""
	for i := 0; i < 5; i++ {
		fmt.Print(modelLabel(cur), " ")
		cur = nextModel(cur)
	}
	fmt.Println()
	// Output:
	// default opus sonnet haiku default
}

// Example_filterSqliteOutput scrubs meta lines a user's ~/.sqliterc may add.
func Example_filterSqliteOutput() {
	fmt.Println(filterSqliteOutput([]byte(".timer on\nRun Time: real 0.001\n$1.23\n")))
	// Output:
	// $1.23
}

// Example_parseSession decodes a saved /resume session.
func Example_parseSession() {
	s := parseSession([]byte(`[{"Who":"you","Text":"hi"},{"Who":"claude","Text":"hello"}]`))
	for _, l := range s {
		fmt.Printf("%s: %s\n", l.who, l.text)
	}
	fmt.Println(parseSession([]byte("not json")) == nil)
	// Output:
	// you: hi
	// claude: hello
	// true
}

// Example_gatewayURL builds the gateway health-check base URL.
func Example_gatewayURL() {
	fmt.Println(gatewayURL("127.0.0.1", "3456"))
	// Output:
	// http://127.0.0.1:3456
}

// Example_clampi clamps an index into a range.
func Example_clampi() {
	fmt.Println(clampi(-3, 0, 9), clampi(4, 0, 9), clampi(42, 0, 9))
	// Output:
	// 0 4 9
}
