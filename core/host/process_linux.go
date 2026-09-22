// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

// Linux does not need Darwin's zombie-only EPERM exception.
func exitedGroup(int) bool { return false }
