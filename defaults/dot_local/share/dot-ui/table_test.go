// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"io"
	"os"
	"strings"
	"testing"
)

func TestRunTable(t *testing.T) {
	in := "Alias\x1fExpands\x1fTier\nll\x1fls -alFh\x1fcore\ngs\x1fgit status\x1fgit\n"
	var b strings.Builder
	if err := runTable(LoadPalette(), strings.NewReader(in), &b); err != nil {
		t.Fatal(err)
	}
	out := b.String()
	for _, w := range []string{"Alias", "Expands", "Tier", "ll", "ls -alFh", "git status"} {
		if !strings.Contains(out, w) {
			t.Errorf("table missing %q\n%s", w, out)
		}
	}
	// Rounded border is drawn.
	if !strings.Contains(out, "╭") || !strings.Contains(out, "╰") {
		t.Errorf("expected rounded border:\n%s", out)
	}
}

func TestRunTableEmpty(t *testing.T) {
	var b strings.Builder
	if err := runTable(LoadPalette(), strings.NewReader(""), &b); err != nil {
		t.Fatal(err)
	}
	if b.String() != "" {
		t.Errorf("empty input should render nothing, got %q", b.String())
	}
}

func TestRunTableHeaderOnly(t *testing.T) {
	var b strings.Builder
	if err := runTable(LoadPalette(), strings.NewReader("Only\x1fHeaders\n"), &b); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(b.String(), "Only") {
		t.Errorf("header-only table should still render headers:\n%s", b.String())
	}
}

func TestDispatchTable(t *testing.T) {
	inR, inW, _ := os.Pipe()
	outR, outW, _ := os.Pipe()
	oldIn, oldOut := os.Stdin, os.Stdout
	os.Stdin, os.Stdout = inR, outW
	defer func() { os.Stdin, os.Stdout = oldIn, oldOut }()

	go func() {
		io.WriteString(inW, "H1\x1fH2\nv1\x1fv2\n")
		inW.Close()
	}()

	done := make(chan int, 1)
	go func() {
		var errb strings.Builder
		done <- dispatch([]string{"table"}, io.Discard, &errb)
	}()
	code := <-done
	outW.Close()
	b, _ := io.ReadAll(outR)
	if code != 0 {
		t.Fatalf("table dispatch exit=%d", code)
	}
	if !strings.Contains(string(b), "H1") || !strings.Contains(string(b), "v2") {
		t.Errorf("table dispatch output=%q", string(b))
	}
}
