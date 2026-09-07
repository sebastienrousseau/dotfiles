// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// testIdentRe matches the test-function identifiers referenced in FEATURES.md.
var testIdentRe = regexp.MustCompile("`((?:Test|Fuzz|Benchmark|Example)[A-Za-z0-9_]*)`")

// declaredTestFuncs parses every *_test.go file in dir (build tags ignored,
// so unix-only files count too) and returns the set of top-level function
// names.
func declaredTestFuncs(t *testing.T, dir string) map[string]bool {
	t.Helper()
	files, err := filepath.Glob(filepath.Join(dir, "*_test.go"))
	if err != nil {
		t.Fatal(err)
	}
	fset := token.NewFileSet()
	names := map[string]bool{}
	for _, f := range files {
		af, err := parser.ParseFile(fset, f, nil, 0)
		if err != nil {
			t.Fatalf("parse %s: %v", f, err)
		}
		for _, d := range af.Decls {
			if fd, ok := d.(*ast.FuncDecl); ok && fd.Recv == nil {
				names[fd.Name.Name] = true
			}
		}
	}
	return names
}

// featureRows returns the table rows of FEATURES.md as (feature, last cell).
func featureRows(t *testing.T, path string) [][2]string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	var rows [][2]string
	for _, ln := range strings.Split(string(b), "\n") {
		ln = strings.TrimSpace(ln)
		if !strings.HasPrefix(ln, "|") {
			continue
		}
		cells := strings.Split(strings.Trim(ln, "|"), "|")
		if len(cells) < 2 {
			continue
		}
		first := strings.TrimSpace(cells[0])
		last := strings.TrimSpace(cells[len(cells)-1])
		if first == "" || strings.HasPrefix(first, "-") || strings.HasPrefix(first, ":") || strings.EqualFold(first, "area") {
			continue // separator / header
		}
		rows = append(rows, [2]string{strings.TrimSpace(cells[1]), last})
	}
	return rows
}

// TestFeatureMatrixComplete guards FEATURES.md against drift: every row must
// name at least one test function, and every named function must exist in
// this package's test files.
func TestFeatureMatrixComplete(t *testing.T) {
	rows := featureRows(t, "FEATURES.md")
	if len(rows) < 30 {
		t.Fatalf("FEATURES.md lists only %d features — the matrix looks truncated", len(rows))
	}
	have := declaredTestFuncs(t, ".")
	for _, r := range rows {
		feature, cell := r[0], r[1]
		refs := testIdentRe.FindAllStringSubmatch(cell, -1)
		if len(refs) == 0 {
			t.Errorf("feature %q names no test function (last column: %q)", feature, cell)
			continue
		}
		for _, m := range refs {
			if !have[m[1]] {
				t.Errorf("feature %q references %s, which does not exist", feature, m[1])
			}
		}
	}
	t.Logf("feature matrix: %d rows verified", len(rows))
}

// TestFeatureMatrixCoversEveryFuzzAndBenchmark is the reverse direction:
// every Fuzz*/Benchmark* function in the package is referenced by the matrix,
// so a new harness cannot land undocumented.
func TestFeatureMatrixCoversEveryFuzzAndBenchmark(t *testing.T) {
	b, err := os.ReadFile("FEATURES.md")
	if err != nil {
		t.Fatal(err)
	}
	doc := string(b)
	for name := range declaredTestFuncs(t, ".") {
		if strings.HasPrefix(name, "Fuzz") || strings.HasPrefix(name, "Benchmark") {
			if !strings.Contains(doc, "`"+name+"`") {
				t.Errorf("%s is not listed in FEATURES.md", name)
			}
		}
	}
}
