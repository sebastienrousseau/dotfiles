// Self-contained Go module for the OSS-Fuzz harnesses.
//
// The harnesses port the regex / URL-parsing logic from our shell
// scripts into Go so OSS-Fuzz's libFuzzer engine can exercise it.
// Re-port any newly-added user-input-handling shell logic here.

module github.com/sebastienrousseau/dotfiles/oss-fuzz-integration/fuzz

go 1.23
