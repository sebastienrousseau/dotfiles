# Fleet Deployment Architecture

## Deployment Flow

```mermaid
---
title: Fleet Deployment Architecture
---
flowchart TD
    subgraph repo["Git Repository (SSOT)"]
        data[".chezmoidata.toml<br/>theme, profile, machine, features"]
        wallpapers["~/Pictures/Wallpapers/ + System<br/>wallpapers (source of truth)"]
        engine_k["K-Means CIELAB engine<br/>extract-theme.py + rebuild-themes.sh"]
        themes[".chezmoidata/themes.toml<br/>auto-generated, WCAG AAA"]
        hw[".chezmoidata/hardware.toml<br/>machine presets: T2, Surface, Geekom"]
        keys[".chezmoidata/keybinds.toml<br/>modifier hierarchy matrix"]
        tpl[".chezmoitemplates/<br/>reusable partials"]
        configs["dot_config/<br/>50+ app configs as .tmpl"]
        wallpapers --> engine_k --> themes
    end

    repo --> engine["Chezmoi Template Engine<br/>chezmoi apply"]

    engine --> t2["MacBook T2<br/>scale 2.0 | macOS"]
    engine --> sp["Surface Pro<br/>scale 1.5 | Linux"]
    engine --> gk["Geekom A9<br/>scale 1.0 | Linux"]

    subgraph apps["App Configs (per machine)"]
        niri["Niri (WM)"]
        ghostty["Ghostty (Term)"]
        tmux["Tmux (Mux)"]
        nvim["Neovim (Edit)"]
        gtk["GTK (UI)"]
    end

    t2 --> apps
    sp --> apps
    gk --> apps

    themes -. "colors" .-> niri & ghostty & tmux & nvim & gtk

    subgraph hotreload["IPC Hot-Reload Path"]
        direction LR
        user(["User runs dot-theme-sync"]) --> ipc["dot-theme-sync<br/>writes theme choice"]
        ipc --> reload_niri["niri: IPC reload"]
        ipc --> reload_ghostty["ghostty: config reload"]
        ipc --> reload_gtk["GTK: gsettings"]
        ipc --> reload_tmux["tmux: source-file"]
        ipc --> reload_nvim["nvim: RPC colorscheme"]
    end

    style repo fill:#313244,stroke:#cba6f7,color:#cdd6f4
    style engine fill:#45475a,stroke:#89b4fa,color:#cdd6f4
    style apps fill:#313244,stroke:#a6e3a1,color:#cdd6f4
    style hotreload fill:#313244,stroke:#f9e2af,color:#cdd6f4
```

> **Note — Keybind Modifier Hierarchy:** Each input layer owns a
> non-overlapping modifier prefix. The compositor (Super) never collides
> with the multiplexer (Ctrl+a prefix), which never collides with the
> editor (Space leader). `Ctrl+h/j/k/l` is the sole shared binding,
> resolved by `tmux-vim-navigator` interop.

## Keybind Conflict Resolution Matrix

| Modifier | Layer | Owner | Examples |
|---|---|---|---|
| `Super` (Mod) | Compositor | Niri | `Super+1`-`9` workspaces, `Super+Enter` terminal |
| `Alt` | Window Switch | Niri | `Alt+Tab`, `Alt+grave` |
| `Ctrl+a` prefix | Multiplexer | Tmux | `Ctrl+a h/j/k/l` panes, `Ctrl+a N` new window |
| `Ctrl+h/j/k/l` | Smart Navigation | Tmux / Neovim | Seamless pane/split traversal |
| `Ctrl+c/v/t/w` | Terminal | Ghostty | Copy, paste, new tab, close |
| `Space` (leader) | Editor | Neovim | `Space+ff` find, `Space+ca` code action |
