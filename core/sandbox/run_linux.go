//go:build linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

// Package sandbox contains the Linux-only process-assurance launcher. It is a
// narrow proof for the hello profile, not a general command sandbox.
package sandbox

import (
	"debug/elf"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"syscall"
	"unsafe"

	"golang.org/x/sys/unix"
)

const (
	maxArtifact     = 65536
	maxAddressSpace = 2 << 30 // leaves headroom for the Go runtime's reserved arenas
	minimumABI      = 3       // includes REFER and TRUNCATE mediation
)

func Run(plugin, stage string) error {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	if err := validate(plugin, stage); err != nil {
		return err
	}
	parent := os.Getppid()
	if parent == 1 {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: parent already exited")
	}
	if err := unix.Prctl(unix.PR_SET_PDEATHSIG, uintptr(syscall.SIGKILL), 0, 0, 0); err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: parent-death signal: %w", err)
	}
	if os.Getppid() != parent {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: parent exited during setup")
	}
	if err := limits(); err != nil {
		return err
	}
	unix.Umask(0077)
	if err := unix.Prctl(unix.PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0); err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: no-new-privileges: %w", err)
	}
	if err := restrictPaths(plugin, stage); err != nil {
		return err
	}
	if err := restrictSyscalls(); err != nil {
		return err
	}
	// Descriptors core passed down (the runner and plugin images) must not
	// reach the plugin. Exec of /proc/self/fd/4 still works: the kernel
	// resolves the path before close-on-exec takes effect.
	if err := unix.CloseRange(3, ^uint(0), unix.CLOSE_RANGE_CLOEXEC); err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: close inherited descriptors: %w", err)
	}
	return unix.Exec(plugin, []string{plugin}, []string{"LANG=C", "DOT_STAGE_ROOT=" + stage})
}

func validate(plugin, stage string) error {
	if !filepath.IsAbs(plugin) || !filepath.IsAbs(stage) || os.Getenv("DOT_STAGE_ROOT") != stage {
		return fmt.Errorf("DOT_E_POLICY: exact absolute sandbox paths required")
	}
	var pi os.FileInfo
	var err error
	if plugin == "/proc/self/fd/4" {
		// Core passes the already-verified plugin as inherited descriptor 4.
		// Following this single internal descriptor binds validation, Landlock
		// and exec to that open inode rather than a replaceable pathname.
		pi, err = os.Stat(plugin)
	} else {
		pi, err = os.Lstat(plugin)
	}
	if err != nil || !pi.Mode().IsRegular() || pi.Mode().Perm()&0022 != 0 || pi.Size() > 16<<20 {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: sandbox executable policy")
	}
	si, err := os.Lstat(stage)
	if err != nil || !si.IsDir() || si.Mode().Perm() != 0700 {
		return fmt.Errorf("DOT_E_PATH_ESCAPE: sandbox stage policy")
	}
	ps, pok := pi.Sys().(*syscall.Stat_t)
	ss, sok := si.Sys().(*syscall.Stat_t)
	if !pok || !sok || ps.Uid != uint32(os.Geteuid()) || ss.Uid != uint32(os.Geteuid()) {
		return fmt.Errorf("DOT_E_POLICY: sandbox paths must be owned by the effective user")
	}
	if err = validateStaticELF(plugin); err != nil {
		return err
	}
	return nil
}

func validateStaticELF(plugin string) error {
	binary, err := elf.Open(plugin)
	if err != nil {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: process-assured plugin must be an ELF executable: %w", err)
	}
	defer binary.Close()
	if binary.FileHeader.Type != elf.ET_EXEC && binary.FileHeader.Type != elf.ET_DYN {
		return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: process-assured plugin has unsupported ELF type %s", binary.FileHeader.Type)
	}
	for _, program := range binary.Progs {
		if program.Type == elf.PT_INTERP {
			return fmt.Errorf("DOT_E_PLUGIN_IDENTITY: process-assured plugin must be statically linked")
		}
	}
	return nil
}

func limits() error {
	for resource, limit := range map[int]uint64{
		unix.RLIMIT_AS:     maxAddressSpace,
		unix.RLIMIT_CORE:   0,
		unix.RLIMIT_CPU:    2,
		unix.RLIMIT_FSIZE:  maxArtifact,
		unix.RLIMIT_NOFILE: 32,
	} {
		if err := unix.Setrlimit(resource, &unix.Rlimit{Cur: limit, Max: limit}); err != nil {
			return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: resource limit %d: %w", resource, err)
		}
	}
	return nil
}

func landlock(number uintptr, a1, a2, a3 uintptr) (uintptr, error) {
	r1, _, errno := unix.Syscall(number, a1, a2, a3)
	if errno != 0 {
		return 0, errno
	}
	return r1, nil
}

func restrictPaths(plugin, stage string) error {
	version, err := landlock(unix.SYS_LANDLOCK_CREATE_RULESET, 0, 0, unix.LANDLOCK_CREATE_RULESET_VERSION)
	if err != nil || version < minimumABI {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: Landlock ABI %d (need %d): %w", version, minimumABI, err)
	}
	handled := uint64(unix.LANDLOCK_ACCESS_FS_EXECUTE | unix.LANDLOCK_ACCESS_FS_WRITE_FILE |
		unix.LANDLOCK_ACCESS_FS_READ_FILE | unix.LANDLOCK_ACCESS_FS_READ_DIR |
		unix.LANDLOCK_ACCESS_FS_REMOVE_DIR | unix.LANDLOCK_ACCESS_FS_REMOVE_FILE |
		unix.LANDLOCK_ACCESS_FS_MAKE_CHAR | unix.LANDLOCK_ACCESS_FS_MAKE_DIR |
		unix.LANDLOCK_ACCESS_FS_MAKE_REG | unix.LANDLOCK_ACCESS_FS_MAKE_SOCK |
		unix.LANDLOCK_ACCESS_FS_MAKE_FIFO | unix.LANDLOCK_ACCESS_FS_MAKE_BLOCK |
		unix.LANDLOCK_ACCESS_FS_MAKE_SYM | unix.LANDLOCK_ACCESS_FS_REFER |
		unix.LANDLOCK_ACCESS_FS_TRUNCATE)
	attr := unix.LandlockRulesetAttr{Access_fs: handled}
	fd, err := landlock(unix.SYS_LANDLOCK_CREATE_RULESET, uintptr(unsafe.Pointer(&attr)), unsafe.Sizeof(attr.Access_fs), 0)
	if err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: Landlock ruleset: %w", err)
	}
	ruleset := int(fd)
	defer unix.Close(ruleset)
	if err = addPath(ruleset, plugin, uint64(unix.LANDLOCK_ACCESS_FS_EXECUTE|unix.LANDLOCK_ACCESS_FS_READ_FILE)); err != nil {
		return err
	}
	stageAccess := handled &^ uint64(unix.LANDLOCK_ACCESS_FS_EXECUTE|unix.LANDLOCK_ACCESS_FS_MAKE_BLOCK|unix.LANDLOCK_ACCESS_FS_MAKE_CHAR)
	if err = addPath(ruleset, stage, stageAccess); err != nil {
		return err
	}
	if _, err = landlock(unix.SYS_LANDLOCK_RESTRICT_SELF, uintptr(ruleset), 0, 0); err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: Landlock enforcement: %w", err)
	}
	return nil
}

func addPath(ruleset int, path string, access uint64) error {
	parent, err := unix.Open(path, unix.O_PATH|unix.O_CLOEXEC, 0)
	if err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: Landlock path: %w", err)
	}
	defer unix.Close(parent)
	attr := unix.LandlockPathBeneathAttr{Allowed_access: access, Parent_fd: int32(parent)}
	if _, err = landlock(unix.SYS_LANDLOCK_ADD_RULE, uintptr(ruleset), unix.LANDLOCK_RULE_PATH_BENEATH, uintptr(unsafe.Pointer(&attr))); err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: Landlock rule: %w", err)
	}
	return nil
}

func restrictSyscalls() error {
	arch, err := nativeAuditArch()
	if err != nil {
		return err
	}
	denied := []uint32{
		unix.SYS_SOCKET, unix.SYS_SOCKETPAIR, unix.SYS_CONNECT, unix.SYS_BIND,
		unix.SYS_LISTEN, unix.SYS_ACCEPT, unix.SYS_ACCEPT4, unix.SYS_SENDTO,
		unix.SYS_RECVFROM, unix.SYS_SENDMSG, unix.SYS_RECVMSG, unix.SYS_RECVMMSG,
		unix.SYS_SENDMMSG, unix.SYS_SHUTDOWN, unix.SYS_SETSID, unix.SYS_SETPGID,
		unix.SYS_UNSHARE, unix.SYS_SETNS, unix.SYS_PTRACE, unix.SYS_PROCESS_VM_READV,
		unix.SYS_PROCESS_VM_WRITEV, unix.SYS_KCMP, unix.SYS_PIDFD_OPEN,
		unix.SYS_PIDFD_GETFD, unix.SYS_PIDFD_SEND_SIGNAL,
		unix.SYS_KILL, unix.SYS_TKILL, unix.SYS_TGKILL,
		unix.SYS_RT_SIGQUEUEINFO, unix.SYS_RT_TGSIGQUEUEINFO,
		unix.SYS_CLONE3, unix.SYS_MOUNT, unix.SYS_UMOUNT2, unix.SYS_PIVOT_ROOT,
		unix.SYS_CHROOT, unix.SYS_OPEN_TREE, unix.SYS_MOVE_MOUNT, unix.SYS_FSOPEN,
		unix.SYS_FSCONFIG, unix.SYS_FSMOUNT, unix.SYS_FSPICK, unix.SYS_MOUNT_SETATTR,
		unix.SYS_OPEN_BY_HANDLE_AT, unix.SYS_NAME_TO_HANDLE_AT,
		unix.SYS_BPF, unix.SYS_PERF_EVENT_OPEN, unix.SYS_USERFAULTFD,
		unix.SYS_IO_URING_SETUP, unix.SYS_IO_URING_ENTER, unix.SYS_IO_URING_REGISTER,
		unix.SYS_ADD_KEY, unix.SYS_REQUEST_KEY, unix.SYS_KEYCTL,
		unix.SYS_PRCTL, unix.SYS_SECCOMP, unix.SYS_MEMFD_CREATE, unix.SYS_EXECVEAT,
		unix.SYS_FCHMOD, unix.SYS_FCHMODAT, unix.SYS_FCHMODAT2,
		unix.SYS_FCHOWN, unix.SYS_FCHOWNAT,
		unix.SYS_SETXATTR, unix.SYS_LSETXATTR, unix.SYS_FSETXATTR,
		unix.SYS_REMOVEXATTR, unix.SYS_LREMOVEXATTR, unix.SYS_FREMOVEXATTR,
		unix.SYS_SETXATTRAT, unix.SYS_REMOVEXATTRAT, unix.SYS_UTIMENSAT,
		unix.SYS_SETPRIORITY, unix.SYS_SCHED_SETAFFINITY, unix.SYS_SCHED_SETATTR,
		unix.SYS_SCHED_SETPARAM, unix.SYS_SCHED_SETSCHEDULER, unix.SYS_IOPRIO_SET,
		unix.SYS_PROCESS_MADVISE, unix.SYS_PROCESS_MRELEASE,
	}
	denied = append(denied, architectureDeniedSyscalls()...)
	errno := uint32(unix.SECCOMP_RET_ERRNO) | uint32(syscall.EPERM)
	filter := []unix.SockFilter{
		{Code: uint16(unix.BPF_LD | unix.BPF_W | unix.BPF_ABS), K: 4},
		{Code: uint16(unix.BPF_JMP | unix.BPF_JEQ | unix.BPF_K), Jt: 1, K: arch},
		{Code: uint16(unix.BPF_RET | unix.BPF_K), K: uint32(unix.SECCOMP_RET_KILL_PROCESS)},
	}
	filter = append(filter, architectureSyscallGuard()...)
	filter = append(filter, []unix.SockFilter{
		{Code: uint16(unix.BPF_LD | unix.BPF_W | unix.BPF_ABS), K: 0},
		// Permit prlimit64 only for the calling process (pid 0). The hard
		// maxima cannot be raised, while another same-UID process stays out
		// of reach.
		{Code: uint16(unix.BPF_JMP | unix.BPF_JEQ | unix.BPF_K), Jf: 4, K: uint32(unix.SYS_PRLIMIT64)},
		{Code: uint16(unix.BPF_LD | unix.BPF_W | unix.BPF_ABS), K: 16},
		{Code: uint16(unix.BPF_JMP | unix.BPF_JEQ | unix.BPF_K), Jt: 1, K: 0},
		{Code: uint16(unix.BPF_RET | unix.BPF_K), K: errno},
		{Code: uint16(unix.BPF_LD | unix.BPF_W | unix.BPF_ABS), K: 0},
		// Go needs clone(2) for runtime threads. Deny namespace/parent escape
		// flags while retaining ordinary threads and same-group children.
		{Code: uint16(unix.BPF_JMP | unix.BPF_JEQ | unix.BPF_K), Jf: 5, K: uint32(unix.SYS_CLONE)},
		{Code: uint16(unix.BPF_LD | unix.BPF_W | unix.BPF_ABS), K: 16},
		{Code: uint16(unix.BPF_JMP | unix.BPF_JSET | unix.BPF_K), Jf: 1, K: uint32(unix.CLONE_NEWNS | unix.CLONE_NEWCGROUP | unix.CLONE_NEWUTS | unix.CLONE_NEWIPC | unix.CLONE_NEWUSER | unix.CLONE_NEWPID | unix.CLONE_NEWNET | unix.CLONE_PARENT | unix.CLONE_PTRACE | unix.CLONE_UNTRACED)},
		{Code: uint16(unix.BPF_RET | unix.BPF_K), K: errno},
		{Code: uint16(unix.BPF_JMP | unix.BPF_JSET | unix.BPF_K), Jt: 1, K: uint32(unix.CLONE_THREAD)},
		{Code: uint16(unix.BPF_RET | unix.BPF_K), K: errno},
		{Code: uint16(unix.BPF_LD | unix.BPF_W | unix.BPF_ABS), K: 0},
	}...)
	for _, number := range denied {
		filter = append(filter,
			unix.SockFilter{Code: uint16(unix.BPF_JMP | unix.BPF_JEQ | unix.BPF_K), Jf: 1, K: number},
			unix.SockFilter{Code: uint16(unix.BPF_RET | unix.BPF_K), K: errno},
		)
	}
	filter = append(filter, unix.SockFilter{Code: uint16(unix.BPF_RET | unix.BPF_K), K: uint32(unix.SECCOMP_RET_ALLOW)})
	program := unix.SockFprog{Len: uint16(len(filter)), Filter: &filter[0]}
	if err = unix.Prctl(unix.PR_SET_SECCOMP, unix.SECCOMP_MODE_FILTER, uintptr(unsafe.Pointer(&program)), 0, 0); err != nil {
		return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: seccomp filter: %w", err)
	}
	return nil
}
