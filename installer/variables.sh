#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451)

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂
appName=dotfiles
backupDirectory=dotfiles_backup
directory=dotfiles
fileVersion=v0.2.451.zip
lang="$(printf '%s' "$LANG" | cut -c 1,2)"
logFile="$logsDirectory/$appName-$(date +%F).log"
logsDirectory="$HOME/.$appName"
progName="$(basename "$0")"
tempDir=$(mktemp -d)

## 🅴🆇🅿🅾🆁🆃🆂
export appName
export backupDirectory
export directory
export fileVersion
export lang
export logsDirectory
export logFile
export progName
export tempDir

#tools=tools
#version=$(git rev-parse --short head)
#webUrl="https://github.com/sebastienrousseau/dotfiles/archive/refs/tags"
