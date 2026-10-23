// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"os/exec"
	"strings"
	"testing"
)

// Every number the cockpit shows traces to a measurement or reads n/a
// (plan v3, T0). Energy is not measured anywhere yet, so no carbon or
// Joule figure may appear, and CPU figures are the sampled values.

func TestDeckShowsNoInventedEnergy(t *testing.T) {
	m := sized()
	m.ecoSnap = EcosystemSnapshot{NumCPU: 8}
	m.cpuHist = nil
	deck := m.renderBtopDeck()
	if !strings.Contains(deck, "SCI n/a") {
		t.Fatalf("energy is not measured, so the deck must say n/a:\n%s", deck)
	}
	for _, invented := range []string{"gCO2", "J ", "GREEN-UMA"} {
		if strings.Contains(deck, invented) {
			t.Fatalf("deck shows %q, which nothing measures:\n%s", invented, deck)
		}
	}
	if bar := formatBtopBar(EcosystemSnapshot{NumCPU: 8}); !strings.Contains(bar, "SCI:n/a") || strings.Contains(bar, "gCO2") {
		t.Fatalf("/eco bar must read SCI:n/a: %q", bar)
	}
}

func TestCPUFiguresAreTheSampledValues(t *testing.T) {
	m := sized()
	m.cpuHist = nil
	m = m.withEco(EcosystemSnapshot{NumCPU: 8, TotalAICPU: 0})
	if got := m.cpuHist[len(m.cpuHist)-1]; got != 0 {
		t.Fatalf("an idle sample is recorded as %v, not 0", got)
	}
	if got := renderMeterBar(cpuBarPct(0), 5); got != "░░░░░" {
		t.Fatalf("0%% CPU draws %q, not an empty bar", got)
	}
	if got := renderBrailleSparkline(nil, 4); strings.Trim(got, "\u2800 ") != "" {
		t.Fatalf("no history yet draws %q, not a blank sparkline", got)
	}
}

func TestGreenSplitStageIsDetectedNotToggled(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }

	m := sized()
	mm, _ := m.handleSlash("/green")
	m = mm.(model)
	if last := m.transcript[len(m.transcript)-1].text; !strings.Contains(last, "unknown command") {
		t.Fatalf("/green no longer exists, got %q", last)
	}
	snap := EcosystemSnapshot{NumCPU: 8}
	snap.Draft.GreenSplit = true
	if got := strings.Join(m.renderDraftCentre(snap), "\n"); !strings.Contains(got, "available") ||
		strings.Contains(got, "gCO2") || strings.Contains(got, "Prefill") {
		t.Fatalf("draft centre must report detection, not invented energy:\n%s", got)
	}
	snap.Draft.GreenSplit = false
	if got := strings.Join(m.renderDraftCentre(snap), "\n"); !strings.Contains(got, "not available") {
		t.Fatalf("draft centre must say when split-stage is unavailable:\n%s", got)
	}
}

func TestActionLabelsMatchTheirCommands(t *testing.T) {
	for _, name := range []string{"claude", "draft", "passmcp", "corralctl"} {
		for _, a := range toolActions(tool{name: name, bin: name}) {
			for _, claim := range []string{"SCI", "carbon", "21031"} {
				if strings.Contains(a.label+a.desc, claim) {
					t.Fatalf("%s action %q promises %q, which %v does not report", name, a.label, claim, a.args)
				}
			}
		}
	}
}
