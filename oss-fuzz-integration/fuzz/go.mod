// Self-contained Go module for the OSS-Fuzz harnesses.
//
// The harnesses port the regex / URL-parsing logic from our shell
// scripts into Go so OSS-Fuzz's libFuzzer engine can exercise it.
// Re-port any newly-added user-input-handling shell logic here.

module github.com/sebastienrousseau/dotfiles/oss-fuzz-integration/fuzz

go 1.23

require (
	github.com/AdaLogics/go-fuzz-headers v0.0.0-20230811130428-ced1acdcaa24 // indirect
	github.com/AdamKorcz/go-118-fuzz-build v0.0.0-20250520111509-a70c2aa677fa // indirect
)
