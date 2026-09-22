//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"fmt"
	"io"
	"os"
	"syscall"
)

func read(root *os.Root, name string) ([]byte, Snapshot, error) {
	var s Snapshot
	f, err := root.OpenFile(name, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if os.IsNotExist(err) {
		return nil, s, nil
	}
	if err != nil {
		return nil, s, err
	}
	defer f.Close()
	i, err := f.Stat()
	if err != nil {
		return nil, s, err
	}
	st, ok := i.Sys().(*syscall.Stat_t)
	if !ok || !i.Mode().IsRegular() || st.Nlink != 1 || i.Size() > MaxFile || i.Mode()&0077 != 0 || i.Mode()&0400 == 0 || i.Mode()&(os.ModeSetuid|os.ModeSetgid|os.ModeSticky) != 0 || st.Uid != uint32(os.Getuid()) {
		return nil, s, fmt.Errorf("DOT_E_POLICY: not a private owned regular file")
	}
	b, err := io.ReadAll(io.LimitReader(f, MaxFile+1))
	if err != nil || len(b) > MaxFile {
		return nil, s, fmt.Errorf("DOT_E_VALIDATION: read limit")
	}
	s = Snapshot{true, Digest(b), uint32(i.Mode().Perm()), st.Uid, st.Gid}
	return b, s, nil
}

func lock(root *os.Root) (*os.File, error) {
	f, err := root.OpenFile(".dot-lock", os.O_CREATE|os.O_RDWR|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return nil, err
	}
	i, err := f.Stat()
	if err != nil {
		f.Close()
		return nil, err
	}
	st := i.Sys().(*syscall.Stat_t)
	if !i.Mode().IsRegular() || st.Nlink != 1 || st.Uid != uint32(os.Getuid()) || i.Mode().Perm() != 0600 {
		f.Close()
		return nil, fmt.Errorf("DOT_E_POLICY: lock identity")
	}
	if err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		return nil, fmt.Errorf("DOT_E_CONFLICT: core already running")
	}
	return f, nil
}

func privateDir(f *os.File) error {
	i, err := f.Stat()
	if err != nil {
		return err
	}
	st := i.Sys().(*syscall.Stat_t)
	if !i.IsDir() || i.Mode().Perm() != 0700 || st.Uid != uint32(os.Getuid()) {
		return fmt.Errorf("DOT_E_POLICY: root must be owned and mode 0700")
	}
	return nil
}
