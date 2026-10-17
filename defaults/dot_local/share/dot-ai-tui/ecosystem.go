// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// ecosystem.go — Unifies corralctl (workspace & Finder-tag telemetry),
// passmcp (9-repo MCP security & risk-graph family), and draft (5-phase
// grounded research & C2PA synthesis) into the dot-ai-tui control plane.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// CorralSummary holds workspace repository health from corralctl.
type CorralSummary struct {
	TotalRepos int
	Pristine   int
	InFlight   int
	Worktree   int
	NeedsFix   int
	Dormant    int
}

// MCPAuditSummary holds passmcp 9-phase diagnostic & passmcp-graph risk state.
type MCPAuditSummary struct {
	ServerName   string
	Score        int
	Grade        string
	PhasesPassed int
	ToxicPairs   int
	Attested     bool
}

// DraftSummary holds draft grounded research & C2PA provenance metrics.
type DraftSummary struct {
	ClaimsVerified int
	CacheHitPct    float64
	C2PAValid      bool
	GreenSplit     bool
}

// EcosystemSnapshot aggregates live ecosystem & runtime telemetry for btop mode.
type EcosystemSnapshot struct {
	Corral       CorralSummary
	MCPServers   int
	PassMCPReady int
	Draft        DraftSummary
	MemAllocMB   float64
	NumGoroutine int
	NumCPU       int
}

// passmcpFamily lists the 6 core binaries of the passmcp 9-repo ecosystem.
var passmcpFamily = []string{
	"passmcp",
	"passmcp-server",
	"passmcp-graph",
	"passmcp-lsp",
	"passmcp-reporting",
	"passmcp-registry",
}

// parseCorralState parses a corralctl .corral-state.json payload and tallies
// repository statuses mapped to macOS Finder tag categories.
func parseCorralState(data []byte) CorralSummary {
	var raw map[string]struct {
		Status   string `json:"status"`
		Dirty    bool   `json:"dirty"`
		Worktree bool   `json:"worktree"`
		Archived bool   `json:"archived"`
	}
	if len(data) == 0 || json.Unmarshal(data, &raw) != nil {
		return CorralSummary{}
	}
	var out CorralSummary
	for _, r := range raw {
		out.TotalRepos++
		switch {
		case r.Status == "error" || r.Status == "needs_fix":
			out.NeedsFix++
		case r.Worktree:
			out.Worktree++
		case r.Dirty || r.Status == "in_flight":
			out.InFlight++
		case r.Archived || r.Status == "dormant":
			out.Dormant++
		default:
			out.Pristine++
		}
	}
	return out
}

// parsePassMCPReport parses a passmcp check JSON scorecard and detects toxic
// tool annotation pairs (destructiveHint + openWorldHint).
func parsePassMCPReport(data []byte) MCPAuditSummary {
	var raw struct {
		Server     string `json:"server"`
		Score      int    `json:"score"`
		PhasesPass int    `json:"phases_passed"`
		Attested   bool   `json:"attested"`
		Tools      []struct {
			Destructive bool `json:"destructiveHint"`
			OpenWorld   bool `json:"openWorldHint"`
		} `json:"tools"`
	}
	if len(data) == 0 || json.Unmarshal(data, &raw) != nil {
		return MCPAuditSummary{Grade: "N/A"}
	}
	score := clampi(raw.Score, 0, 100)
	toxic := 0
	for _, tl := range raw.Tools {
		if tl.Destructive && tl.OpenWorld {
			toxic++
		}
	}
	return MCPAuditSummary{
		ServerName:   clean(raw.Server),
		Score:        score,
		Grade:        scoreToGrade(score),
		PhasesPassed: clampi(raw.PhasesPass, 0, 9),
		ToxicPairs:   toxic,
		Attested:     raw.Attested,
	}
}

func scoreToGrade(score int) string {
	switch {
	case score >= 97:
		return "A+"
	case score >= 90:
		return "A"
	case score >= 80:
		return "B"
	case score >= 70:
		return "C"
	default:
		return "F"
	}
}

// parseDraftProvenance parses a draft --verify --json provenance report.
func parseDraftProvenance(data []byte) DraftSummary {
	var raw struct {
		ClaimsVerified int     `json:"claims_verified"`
		CacheHitPct    float64 `json:"cache_hit_pct"`
		C2PAValid      bool    `json:"c2pa_valid"`
		ExtractEngine  string  `json:"extract_engine"`
	}
	if len(data) == 0 || json.Unmarshal(data, &raw) != nil {
		return DraftSummary{}
	}
	hit := raw.CacheHitPct
	if hit < 0 {
		hit = 0
	}
	if hit > 100 {
		hit = 100
	}
	return DraftSummary{
		ClaimsVerified: max(raw.ClaimsVerified, 0),
		CacheHitPct:    hit,
		C2PAValid:      raw.C2PAValid,
		GreenSplit:     strings.EqualFold(raw.ExtractEngine, "ollama"),
	}
}

// sampleEcosystem gathers a fast, zero-subprocess snapshot of corralctl,
// passmcp, draft, and Go runtime memory telemetry.
func sampleEcosystem() EcosystemSnapshot {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	snap := EcosystemSnapshot{
		MemAllocMB:   float64(ms.Alloc) / (1024.0 * 1024.0),
		NumGoroutine: runtime.NumGoroutine(),
		NumCPU:       runtime.NumCPU(),
	}
	for _, bin := range passmcpFamily {
		if _, err := exec.LookPath(bin); err == nil {
			snap.PassMCPReady++
		}
	}
	home, _ := os.UserHomeDir()
	if b, err := os.ReadFile(filepath.Join(home, "Code", ".corral-state.json")); err == nil {
		snap.Corral = parseCorralState(b)
	}
	mcpCfg := filepath.Join(envOr("XDG_CONFIG_HOME", filepath.Join(home, ".config")), "claude", "mcp_servers.json")
	if b, err := os.ReadFile(mcpCfg); err == nil {
		var cfg struct {
			Servers map[string]json.RawMessage `json:"mcpServers"`
		}
		if json.Unmarshal(b, &cfg) == nil {
			snap.MCPServers = len(cfg.Servers)
		}
	}
	_, ollamaErr := exec.LookPath("ollama")
	_, draftErr := exec.LookPath("draft")
	snap.Draft.GreenSplit = ollamaErr == nil && draftErr == nil
	return snap
}

// formatBtopBar formats a one-line btop telemetry summary bar for the header/splash.
func formatBtopBar(snap EcosystemSnapshot, sci SCIMetrics, greenMode bool) string {
	mode := "STD"
	if greenMode {
		mode = "GREEN-UMA"
	}
	return fmt.Sprintf("CPU:%dc · RAM:%.1fMB · MCP:%d · passmcp:%d/%d · Corral:%d · SCI:%.2fgCO2eq [%s]",
		snap.NumCPU, snap.MemAllocMB, snap.MCPServers, snap.PassMCPReady, len(passmcpFamily),
		snap.Corral.TotalRepos, sci.GCO2eq, mode)
}
