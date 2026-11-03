package config

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"strings"
)

// loadAPIKey creates a per-installation key for portable releases.
func loadAPIKey() error {
	if os.Getenv("API_KEY_SERVER") != "auto" {
		return nil
	}
	const path = "cert/api.key"
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		var key [32]byte
		if _, err := rand.Read(key[:]); err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return err
		}
		data = []byte(hex.EncodeToString(key[:]))
		file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			return err
		}
		_, err = file.Write(data)
		if err = errors.Join(err, file.Close()); err != nil {
			_ = os.Remove(path)
			return err
		}
	} else if err != nil {
		return err
	}
	key := strings.TrimSpace(string(data))
	if bytes, err := hex.DecodeString(key); err != nil || len(bytes) != 32 {
		return errors.New("cert/api.key 无效")
	}
	return os.Setenv("API_KEY_SERVER", key)
}
