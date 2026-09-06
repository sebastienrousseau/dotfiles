// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
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

// TestDispatchTable covers `dot-ui table` end-to-end through dispatch.
func TestDispatchTable(t *testing.T) {
	var out, errb strings.Builder
	code := dispatch([]string{"table"}, strings.NewReader("H1\x1fH2\nv1\x1fv2\n"), &out, &errb)
	if code != 0 {
		t.Fatalf("table dispatch exit=%d stderr=%q", code, errb.String())
	}
	if !strings.Contains(out.String(), "H1") || !strings.Contains(out.String(), "v2") {
		t.Errorf("table dispatch output=%q", out.String())
	}
}

// TestRunTableRaggedRows covers rows with fewer/more cells than the header.
func TestRunTableRaggedRows(t *testing.T) {
	var b strings.Builder
	in := "A\x1fB\x1fC\nonly-one\nx\x1fy\x1fz\x1fextra\n"
	if err := runTable(LoadPalette(), strings.NewReader(in), &b); err != nil {
		t.Fatal(err)
	}
	for _, w := range []string{"A", "only-one", "z"} {
		if !strings.Contains(b.String(), w) {
			t.Errorf("ragged table missing %q\n%s", w, b.String())
		}
	}
}

// TestRunTableWriteError covers the propagated write error.
func TestRunTableWriteError(t *testing.T) {
	if err := runTable(LoadPalette(), strings.NewReader("H\nv\n"), errWriter{}); err == nil {
		t.Fatal("write error must propagate")
	}
}
