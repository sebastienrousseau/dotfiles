// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// ecosystem.go — Unifies live OS process telemetry (AI agents, MCP servers,
// local LLMs), corralctl (workspace & Finder-tag telemetry), passmcp (9-repo
// MCP security & risk-graph family), and draft (5-phase grounded research &
// C2PA synthesis) into the dot-ai-tui btop control plane.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// AIProcess represents a live OS process belonging to the AI fleet, local LLM
// runtimes, gateway, or MCP / ecosystem toolchains.
type AIProcess struct {
	PID     int
	Name    string
	Role    string
	CPUPct  float64
	MemMB   float64
	Elapsed string
}

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

// EcosystemSnapshot aggregates live ecosystem, OS process, and runtime telemetry.
type EcosystemSnapshot struct {
	Corral       CorralSummary
	MCPServers   int
	PassMCPReady int
	Draft        DraftSummary
	MemAllocMB   float64
	NumGoroutine int
	NumCPU       int
	ActiveProcs  []AIProcess
	ToolProcs    map[string]int
	TotalAICPU   float64
	TotalAIMemMB float64
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

// ownRoles maps dot's own processes to their btop process table role. Every
// AI tool's processes come from the roster (rosterRoles, roster_gen.go).
var ownRoles = map[string]string{
	"dot-mcp": "mcp", "dot-ai-proxy": "gateway",
}

// aiProcessRole returns the btop role category for a process command name, or "".
func aiProcessRole(comm string) string {
	base := strings.TrimSpace(filepath.Base(comm))
	if role, ok := rosterRoles[base]; ok {
		return role
	}
	return ownRoles[base]
}

// parsePsProcesses parses `ps -axo pid=,pcpu=,rss=,etime=,comm=` output into
// a CPU-sorted slice of active AI, LLM, gateway, and MCP processes.
func parsePsProcesses(data []byte) []AIProcess {
	if len(data) == 0 {
		return nil
	}
	var out []AIProcess
	for _, ln := range strings.Split(string(data), "\n") {
		f := strings.Fields(ln)
		if len(f) < 5 {
			continue
		}
		comm := strings.Join(f[4:], " ")
		role := aiProcessRole(comm)
		if role == "" {
			continue
		}
		pid, err := strconv.Atoi(f[0])
		if err != nil || pid <= 0 {
			continue
		}
		cpu, _ := strconv.ParseFloat(f[1], 64)
		rssKB, _ := strconv.ParseFloat(f[2], 64)
		out = append(out, AIProcess{
			PID:     pid,
			Name:    filepath.Base(comm),
			Role:    role,
			CPUPct:  max(cpu, 0),
			MemMB:   max(rssKB/1024.0, 0),
			Elapsed: clean(f[3]),
		})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].CPUPct != out[j].CPUPct {
			return out[i].CPUPct > out[j].CPUPct
		}
		return out[i].MemMB > out[j].MemMB
	})
	return out
}

var (
	psCacheMu   sync.Mutex
	psCacheTime time.Time
	psCacheData []byte
	psRunner    = defaultPsRunner
)

func defaultPsRunner() []byte {
	psCacheMu.Lock()
	defer psCacheMu.Unlock()
	if time.Since(psCacheTime) < 1500*time.Millisecond && psCacheData != nil {
		return psCacheData
	}
	out, err := exec.Command("ps", "-axo", "pid=,pcpu=,rss=,etime=,comm=").Output()
	if err != nil {
		return nil
	}
	psCacheData = out
	psCacheTime = time.Now()
	return out
}

// scanCodeDirs scans ~/Code and its standard portfolio subdirectories
// (Public, Private, Work, Forks) for git repositories when .corral-state.json
// is not present.
func scanCodeDirs(codeDir string) CorralSummary {
	var out CorralSummary
	roots := []string{
		codeDir,
		filepath.Join(codeDir, "Public"),
		filepath.Join(codeDir, "Private"),
		filepath.Join(codeDir, "Work"),
		filepath.Join(codeDir, "Forks"),
	}
	for _, root := range roots {
		entries, err := os.ReadDir(root)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() {
				inspectGitEntry(filepath.Join(root, e.Name()), &out)
			}
		}
	}
	return out
}

func inspectGitEntry(dir string, out *CorralSummary) {
	fi, err := os.Stat(filepath.Join(dir, ".git"))
	if err != nil {
		return
	}
	out.TotalRepos++
	if fi.IsDir() {
		out.Pristine++
	} else {
		out.Worktree++
	}
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

// sampleEcosystem gathers a snapshot of active AI/MCP OS processes, corralctl,
// passmcp, draft, and Go runtime memory telemetry.
func sampleEcosystem() EcosystemSnapshot {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	procs := parsePsProcesses(psRunner())
	toolProcs := make(map[string]int, len(procs))
	var totCPU, totMem float64
	for _, p := range procs {
		toolProcs[p.Name]++
		totCPU += p.CPUPct
		totMem += p.MemMB
	}
	snap := EcosystemSnapshot{
		MemAllocMB:   float64(ms.Alloc) / (1024.0 * 1024.0),
		NumGoroutine: runtime.NumGoroutine(),
		NumCPU:       runtime.NumCPU(),
		ActiveProcs:  procs,
		ToolProcs:    toolProcs,
		TotalAICPU:   totCPU,
		TotalAIMemMB: totMem,
	}
	for _, bin := range passmcpFamily {
		if _, err := exec.LookPath(bin); err == nil {
			snap.PassMCPReady++
		}
	}
	home, _ := os.UserHomeDir()
	codeDir := filepath.Join(home, "Code")
	if b, err := os.ReadFile(filepath.Join(codeDir, ".corral-state.json")); err == nil {
		snap.Corral = parseCorralState(b)
	} else {
		snap.Corral = scanCodeDirs(codeDir)
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
// Energy is not measured, so SCI reads n/a.
func formatBtopBar(snap EcosystemSnapshot) string {
	return fmt.Sprintf("CPU:%dc(%.1f%%) · AI-RAM:%.1fMB · Procs:%d · MCP:%d · passmcp:%d/%d · Corral:%d · SCI:n/a",
		snap.NumCPU, snap.TotalAICPU, snap.TotalAIMemMB, len(snap.ActiveProcs),
		snap.MCPServers, snap.PassMCPReady, len(passmcpFamily),
		snap.Corral.TotalRepos)
}
