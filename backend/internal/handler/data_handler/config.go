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

// modules 模块注册表。
//
// staticDir 由调用方传入而非常量：STATIC_DIR 可配置，且包级变量初始化早于
// config.Load()，因此不能在包初始化时读取配置。
func modules(staticDir string) []ModuleConfig {
	return []ModuleConfig{
		{
			Name:     "booklet",
			ImageDir: filepath.Join(staticDir, "img_storage", "booklet"),
			IsDB:     true,
		},
		{
			Name:     "essay",
			ImageDir: filepath.Join(staticDir, "img_storage", "essay"),
			IsDB:     true,
		},
		{
			Name:      "preferences",
			JSONFiles: []string{filepath.Join(staticDir, "preferences", "preferences.json")},
			ImageDir:  filepath.Join(staticDir, "img_storage", "preferences"),
			IsDB:      false,
		},
	}
}

// FindModuleConfigByName 根据模块名称查找其配置（未找到返回 nil）。
func FindModuleConfigByName(name string) *ModuleConfig {
	all := modules(config.AppConf.StaticDir)
	for i := range all {
		if all[i].Name == name {
			return &all[i]
		}
	}
	return nil
}
