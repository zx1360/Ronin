package data_handler

import (
	"path/filepath"

	"monarch/internal/config"
)

// ModuleConfig 单个用户数据模块的存储方式。
type ModuleConfig struct {
	Name      string   // 模块名称，用于路由，如 "booklet", "essay"
	JSONFiles []string // JSON 文件模式下的数据文件路径（DB 模块为空）
	ImageDir  string   // 图片文件存储目录
	IsDB      bool     // true=读写数据库表，false=读写 JSON 文件
}

func modules(dataDir string) []ModuleConfig {
	return []ModuleConfig{
		{
			Name:     "booklet",
			ImageDir: filepath.Join(dataDir, "img_storage", "booklet"),
			IsDB:     true,
		},
		{
			Name:     "essay",
			ImageDir: filepath.Join(dataDir, "img_storage", "essay"),
			IsDB:     true,
		},
		{
			Name:      "preferences",
			JSONFiles: []string{filepath.Join(dataDir, "preferences", "preferences.json")},
			ImageDir:  filepath.Join(dataDir, "img_storage", "preferences"),
			IsDB:      false,
		},
	}
}

// FindModuleConfigByName 根据模块名称查找其配置（未找到返回 nil）。
func FindModuleConfigByName(name string) *ModuleConfig {
	all := modules(config.AppConf.DataDir)
	for i := range all {
		if all[i].Name == name {
			return &all[i]
		}
	}
	return nil
}
