// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

//go:build linux

package main

import (
	"bytes"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
)

func main() {
	stage := os.Getenv("DOT_STAGE_ROOT")
	outside, err := os.ReadFile(filepath.Join(stage, "outside-path"))
	if err != nil {
		panic(err)
	}
	outsidePath := string(bytes.TrimSpace(outside))
	if _, err = os.ReadFile(outsidePath); !errors.Is(err, os.ErrPermission) {
		panic(fmt.Sprintf("outside read result: %v", err))
	}
	if err = os.WriteFile(outsidePath, []byte("changed"), 0600); !errors.Is(err, os.ErrPermission) {
		panic(fmt.Sprintf("outside write result: %v", err))
	}
	if err = os.Chmod(outsidePath, 0644); !errors.Is(err, os.ErrPermission) {
		panic(fmt.Sprintf("outside metadata result: %v", err))
	}
	if listener, listenErr := net.Listen("tcp", "127.0.0.1:0"); !errors.Is(listenErr, syscall.EPERM) {
		if listener != nil {
			listener.Close()
		}
		panic(fmt.Sprintf("network result: %v", listenErr))
	} else if listener != nil {
		listener.Close()
	}
	if _, err = syscall.Setsid(); !errors.Is(err, syscall.EPERM) {
		panic(fmt.Sprintf("process-group escape result: %v", err))
	}
	if _, _, errno := syscall.RawSyscall(syscall.SYS_UNSHARE, uintptr(syscall.CLONE_NEWUSER), 0, 0); errno != syscall.EPERM {
		panic(fmt.Sprintf("namespace escape result: %v", errno))
	}
	if _, _, errno := syscall.RawSyscall(syscall.SYS_PRCTL, uintptr(syscall.PR_SET_PDEATHSIG), 0, 0); errno != syscall.EPERM {
		panic(fmt.Sprintf("parent-death reset result: %v", errno))
	}
	if _, _, errno := syscall.RawSyscall(syscall.SYS_MEMFD_CREATE, 0, 0, 0); errno != syscall.EPERM {
		panic(fmt.Sprintf("anonymous executable result: %v", errno))
	}
	if _, _, errno := syscall.RawSyscall6(syscall.SYS_EXECVEAT, 0, 0, 0, 0, 0, 0); errno != syscall.EPERM {
		panic(fmt.Sprintf("execveat result: %v", errno))
	}
	if err = exec.Command("/bin/true").Run(); !errors.Is(err, os.ErrPermission) {
		panic(fmt.Sprintf("unapproved executable result: %v", err))
	}
	for resource, want := range map[int]uint64{
		syscall.RLIMIT_AS: 1 << 30, syscall.RLIMIT_CORE: 0, syscall.RLIMIT_CPU: 2,
		syscall.RLIMIT_FSIZE: 65536, syscall.RLIMIT_NOFILE: 32,
	} {
		var limit syscall.Rlimit
		if err = syscall.Getrlimit(resource, &limit); err != nil || limit.Cur != want || limit.Max != want {
			panic(fmt.Sprintf("resource limit %d: %#v %v", resource, limit, err))
		}
	}
	if err = os.WriteFile(filepath.Join(stage, "contained"), []byte("ok\n"), 0600); err != nil {
		panic(err)
	}
	fmt.Println("contained")
}
