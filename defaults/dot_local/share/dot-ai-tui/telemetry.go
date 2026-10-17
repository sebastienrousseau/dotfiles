// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// telemetry.go — btop-grade Braille sparklines, ISO/IEC 21031:2024 Software
// Carbon Intensity (SCI) & Zeus prefill/decode Joule modeling, IAL-Scan
// runaway agent loop entropy detection, and the native --log-event fast path.
package main

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

// SCIMetrics holds phase-disaggregated energy (Zeus, arXiv:2601.22076),
// prompt-cache energy savings (GreenCache, arXiv:2505.23970), and ISO/IEC
// 21031:2024 Software Carbon Intensity (SCI) metrics.
type SCIMetrics struct {
	PrefillJoules float64
	DecodeJoules  float64
	CacheSavedWh  float64
	TotalJoules   float64
	GCO2eq        float64
	SCIPer1kTok   float64
}

// brailleLeft and brailleRight map 0..4 vertical fill levels in a 2x4
// Unicode Braille cell (U+2800..U+28FF) from bottom to top.
var (
	brailleLeft  = [5]rune{0x00, 0x40, 0x44, 0x46, 0x47}
	brailleRight = [5]rune{0x00, 0x80, 0xA0, 0xB0, 0xB8}
)

// renderBrailleSparkline renders a btop-style high-resolution Braille
// sparkline of width cells (2 samples per cell, 4 vertical levels per sample).
func renderBrailleSparkline(samples []float64, width int) string {
	if width < 1 {
		return ""
	}
	if len(samples) == 0 {
		return strings.Repeat(string(rune(0x2800)), width)
	}
	lo, hi := samples[0], samples[0]
	for _, v := range samples[1:] {
		if math.IsNaN(v) || math.IsInf(v, 0) {
			continue
		}
		if v < lo {
			lo = v
		}
		if v > hi {
			hi = v
		}
	}
	span := hi - lo
	need := width * 2
	var b strings.Builder
	b.Grow(width * 3)
	for col := 0; col < width; col++ {
		idxL := len(samples) - need + col*2
		idxR := idxL + 1
		lvlL := sampleToLevel(samples, idxL, lo, span)
		lvlR := sampleToLevel(samples, idxR, lo, span)
		b.WriteRune(0x2800 + brailleLeft[lvlL] + brailleRight[lvlR])
	}
	return b.String()
}

func sampleToLevel(samples []float64, idx int, lo, span float64) int {
	if idx < 0 || idx >= len(samples) {
		return 0
	}
	v := samples[idx]
	if math.IsNaN(v) || math.IsInf(v, 0) {
		return 0
	}
	if span <= 1e-9 {
		if v > 0 {
			return 2
		}
		return 0
	}
	norm := (v - lo) / span
	lvl := int(math.Round(norm * 4.0))
	return clampi(lvl, 0, 4)
}

// renderMeterBar renders a compact btop-style percentage bar of width cells.
func renderMeterBar(pct float64, width int) string {
	if width < 1 {
		return ""
	}
	if math.IsNaN(pct) || pct < 0 {
		pct = 0
	}
	if pct > 100 {
		pct = 100
	}
	filled := clampi(int(math.Round((pct/100.0)*float64(width))), 0, width)
	return strings.Repeat("█", filled) + strings.Repeat("░", width-filled)
}

// computeSCI calculates phase-separated prefill/decode Joules and ISO/IEC
// 21031:2024 Software Carbon Intensity: SCI = ((E * I) + M) / R.
func computeSCI(inputTokens, cachedTokens, outputTokens, reasoningTokens int, localJoules, gridIntensity float64) SCIMetrics {
	inTok := max(inputTokens, 0)
	cacheTok := clampi(cachedTokens, 0, inTok)
	uncachedIn := inTok - cacheTok
	outTok := max(outputTokens, 0) + max(reasoningTokens, 0)
	if math.IsNaN(localJoules) || math.IsInf(localJoules, 0) || localJoules < 0 {
		localJoules = 0
	}
	if math.IsNaN(gridIntensity) || math.IsInf(gridIntensity, 0) || gridIntensity <= 0 {
		gridIntensity = 380.0
	}

	// Compute-bound prefill vs memory-bandwidth-bound decode (Zeus model).
	prefillJ := float64(uncachedIn)*0.00018 + float64(cacheTok)*0.000018
	decodeJ := float64(outTok) * 0.00142
	savedJ := float64(cacheTok) * (0.00018 - 0.000018)
	totalJ := prefillJ + decodeJ + localJoules

	// Convert Joules to kWh (1 kWh = 3.6e6 J) and add amortized embodied M.
	kwh := totalJ / 3600000.0
	embodiedG := float64(inTok+outTok) * 0.0000025
	gco2 := (kwh * gridIntensity) + embodiedG

	totalTok := inTok + outTok
	sciPer1k := gco2
	if totalTok > 0 {
		sciPer1k = (gco2 / float64(totalTok)) * 1000.0
	}
	return SCIMetrics{
		PrefillJoules: prefillJ,
		DecodeJoules:  decodeJ,
		CacheSavedWh:  savedJ / 3600.0,
		TotalJoules:   totalJ,
		GCO2eq:        gco2,
		SCIPer1kTok:   sciPer1k,
	}
}

// computeActionEntropy implements IAL-Scan (arXiv:2607.01641) trajectory
// Shannon entropy and consecutive duplicate detection for agent tool calls.
func computeActionEntropy(actions []string) (float64, bool) {
	n := len(actions)
	if n == 0 {
		return 0, false
	}
	if n >= 3 {
		last := actions[n-1]
		if last != "" && actions[n-2] == last && actions[n-3] == last {
			return 0, true
		}
	}
	counts := make(map[string]int, n)
	for _, a := range actions {
		counts[a]++
	}
	var h float64
	fn := float64(n)
	for _, c := range counts {
		p := float64(c) / fn
		h -= p * math.Log2(p)
	}
	looping := n >= 6 && h < 0.35
	return h, looping
}

// logEventCLI records a CLI run directly to dotfiles-ai.db (--log-event).
func logEventCLI(args []string) error {
	if len(args) < 6 {
		return fmt.Errorf("usage: --log-event <provider> <project> <exit_code> <dur> <pw> <ts>")
	}
	provider, project := sanitizeSQLString(args[0]), sanitizeSQLString(args[1])
	ec, _ := strconv.Atoi(args[2])
	dur, _ := strconv.ParseFloat(args[3], 64)
	pw, _ := strconv.Atoi(args[4])
	ts := sanitizeSQLString(args[5])
	sci := computeSCI(pw*2, 0, pw*4, 0, dur*9.5, 380.0)
	sqlStmt := fmt.Sprintf(
		"PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS runs (id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT NOT NULL DEFAULT '', delegate TEXT NOT NULL DEFAULT '', model TEXT NOT NULL DEFAULT '', project TEXT NOT NULL DEFAULT '', exit_code INTEGER DEFAULT 0, duration_secs REAL DEFAULT 0, prompt_words INTEGER DEFAULT 0, cost_usd REAL DEFAULT 0, joules REAL DEFAULT 0, gco2eq REAL DEFAULT 0); INSERT INTO runs (ts,delegate,model,project,exit_code,duration_secs,prompt_words,joules,gco2eq) VALUES ('%s','%s','%s','%s',%d,%.4f,%d,%.4f,%.6f);",
		ts, provider, provider, project, ec, dur, pw, sci.TotalJoules, sci.GCO2eq,
	)
	return execCommand("sqlite3", "-batch", "-init", "/dev/null", dbPath(), sqlStmt).Run()
}

func sanitizeSQLString(s string) string {
	return strings.ReplaceAll(clean(s), "'", "''")
}
