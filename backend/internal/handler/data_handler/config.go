package data_handler

import (
	"path/filepath"

	"monarch/internal/config"
)

func validModule(name string) bool {
	return name == "booklet" || name == "essay" || name == "preferences"
}

func moduleImageDir(name string) string {
	return filepath.Join(config.AppConf.DataDir, "img_storage", name)
}

func preferencesPath() string {
	return filepath.Join(config.AppConf.DataDir, "preferences", "preferences.json")
}
