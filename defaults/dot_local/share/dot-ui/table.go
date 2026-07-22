// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// `dot-ui table` — a static, theme-aware table.
//
// Reads unit-separator (\x1f) delimited rows on stdin: the first line is the
// header, the rest are data rows. Renders a rounded lipgloss table themed to
// the active wallpaper and prints it to stdout. It is a swap-in for the
// gum-table branch of lib/dot/ui.sh's ui_table_end, so every list/table
// command gets the same look. No terminal takeover — safe to pipe.
package main

import (
	"bufio"
	"io"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/lipgloss/table"
)

const unitSep = "\x1f"

func runTable(p Palette, in io.Reader, out io.Writer) error {
	sc := bufio.NewScanner(in)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	var headers []string
	var rows [][]string
	for sc.Scan() {
		fields := strings.Split(sc.Text(), unitSep)
		if headers == nil {
			headers = fields
			continue
		}
		rows = append(rows, fields)
	}
	if len(headers) == 0 {
		return nil
	}

	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(p.Accent).Padding(0, 1)
	cellStyle := lipgloss.NewStyle().Foreground(p.Fg).Padding(0, 1)

	t := table.New().
		Border(lipgloss.RoundedBorder()).
		BorderStyle(lipgloss.NewStyle().Foreground(p.Border)).
		Headers(headers...).
		Rows(rows...).
		StyleFunc(func(row, _ int) lipgloss.Style {
			if row == table.HeaderRow {
				return headerStyle
			}
			return cellStyle
		})

	// Indent by two spaces to match ui.sh's layout.
	rendered := "  " + strings.ReplaceAll(t.String(), "\n", "\n  ")
	_, err := io.WriteString(out, rendered+"\n")
	return err
}
