//go:build linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"fmt"
	"os"
	"os/exec"
)

func descriptorPath(fd int) string {
	return fmt.Sprintf("/proc/self/fd/%d", fd)
}

// descriptorCommand executes the already-open inode as descriptor 3. Files in
// inherited become descriptors 4 onward. Replacing a pathname after validation
// therefore cannot change the executable image selected by the child.
func descriptorCommand(ctx context.Context, executable *os.File, inherited []*os.File, args ...string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, descriptorPath(3), args...)
	cmd.ExtraFiles = append([]*os.File{executable}, inherited...)
	return cmd
}
