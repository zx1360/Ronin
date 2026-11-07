package main

import (
	"os"

	"golang.org/x/sys/windows"
)

func tryLock(file *os.File) error {
	var offset windows.Overlapped
	return windows.LockFileEx(windows.Handle(file.Fd()),
		windows.LOCKFILE_EXCLUSIVE_LOCK|windows.LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &offset)
}
