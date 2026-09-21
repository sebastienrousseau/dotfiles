# Explicit consumer tests

These tests require their declared external runtime and are not auto-discovered by
the native shell integration suite. They must fail if prerequisites are missing in
their dedicated lane; do not turn a missing Docker runtime into a passing smoke.

`bash tests/consumer/test_npx_clean_container.sh 0.2.522` performs a real published
npm installation in a fresh Linux container. It requires a running Docker engine
and network access; it mounts no host home, repository, credentials or socket.
The `npm-consumer` job in `core-contracts.yml` gates this scenario on Linux. The
macOS native integration suite does not provision a Linux VM for this test.
