# Fixed-bug regression corpus

One directory per fuzz target. Every input here is the minimised
reproducer of a crash or assertion failure that a fuzz target once found
and that has since been fixed. CI replays each directory with
`-runs=0` on every push, so a fixed bug cannot silently return.

To add one after fixing a finding:

```sh
cargo +nightly fuzz tmin <target> fuzz/artifacts/<target>/crash-<hash>
cp fuzz/artifacts/<target>/minimized-from-<hash> \
   fuzz/regressions/<target>/<short-description>
```

The `.gitkeep` files only keep otherwise-empty directories in git.
libFuzzer skips dot-files, so replaying an empty regression directory is a
no-op rather than an extra test case.
