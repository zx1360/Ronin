package galleryfs

import (
	"crypto/sha256"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const (
	Raw     = "Raw"
	Media   = "Media"
	Thumbs  = "Thumbs"
	Preview = "Preview"
	Deleted = "Deleted"
)

func RelativePath(path string) (string, bool) {
	path = filepath.Clean(filepath.FromSlash(strings.TrimSpace(path)))
	return path, path != "." && filepath.IsLocal(path)
}

func HashFile(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, f); err != nil {
		return nil, err
	}
	return hash.Sum(nil), nil
}
