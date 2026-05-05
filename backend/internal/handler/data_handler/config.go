// data/config.go
package data_handler

import (
	"path/filepath"
)

type ModuleConfig struct {
	Name      string   // 模块名称，用于路由，如 "booklet", "essay"
	JSONFiles []string // 需要同步或备份的JSON数据文件路径列表（DB 模块此字段为空）
	ImageDir  string   // 图片文件存储目录路径
	IsDB      bool     // 是否使用数据库存储（true=DB表，false=JSON文件）
}

// AppDir 是你的应用根目录。在Go中，我们通常使用工作目录。
// 为了方便，你可以直接在 handlers 中使用相对路径 "static"。
// 这里定义它是为了保持与你Dart思路的一致性。
const AppDir = "."

// Modules 是所有模块的配置列表
var Modules = []ModuleConfig{
	{
		Name:      "booklet",
		JSONFiles: nil, // 已迁移至数据库 user_data.booklet_styles / booklet_records
		ImageDir:  filepath.Join(AppDir, "static", "img_storage", "booklet"),
		IsDB:      true,
	},
	{
		Name:      "essay",
		JSONFiles: nil, // 已迁移至数据库 user_data.essay_articles / essay_labels / essay_year_summaries
		ImageDir:  filepath.Join(AppDir, "static", "img_storage", "essay"),
		IsDB:      true,
	},
	{
		Name: "preferences",
		JSONFiles: []string{
			filepath.Join(AppDir, "static", "preferences", "preferences.json"),
		},
		ImageDir: filepath.Join(AppDir, "static", "img_storage", "preferences"),
		IsDB:     false,
	},
}

// FindModuleConfigByName 根据模块名称查找其配置
func FindModuleConfigByName(name string) *ModuleConfig {
	for i := range Modules {
		if Modules[i].Name == name {
			return &Modules[i]
		}
	}
	return nil
}
