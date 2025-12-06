// data/config.go
package data_handler

import (
	"fmt"
	"path/filepath"
)

type ModuleConfig struct {
	Name      string   // 模块名称，用于路由，如 "booklet", "essay"
	JSONFiles []string // 需要同步或备份的JSON数据文件路径列表
	ImageDir  string   // 图片文件存储目录路径
}

// AppDir 是你的应用根目录。在Go中，我们通常使用工作目录。
// 为了方便，你可以直接在 handlers 中使用相对路径 "static"。
// 这里定义它是为了保持与你Dart思路的一致性。
const AppDir = "."

// Modules 是所有模块的配置列表
var Modules = []ModuleConfig{
	{
		Name: "booklet",
		JSONFiles: []string{
			filepath.Join(AppDir, "static", "booklet", "styles.json"),
			filepath.Join(AppDir, "static", "booklet", "records.json"),
		},
		ImageDir: filepath.Join(AppDir, "static", "img_storage", "booklet"),
	},
	{
		Name: "essay",
		JSONFiles: []string{
			filepath.Join(AppDir, "static", "essay", "essays.json"),
			filepath.Join(AppDir, "static", "essay", "labels.json"),
			filepath.Join(AppDir, "static", "essay", "year_summaries.json"),
		},
		ImageDir: filepath.Join(AppDir, "static", "img_storage", "essay"),
	},
	// 在这里添加更多模块...
	// {
	//  Name: "new_module",
	//  JSONFiles: []string{...},
	//  ImageDir: "...",
	// },
}

// FindModuleConfigByName 根据模块名称查找其配置
func FindModuleConfigByName(name string) *ModuleConfig {
	fmt.Println(filepath.Join(AppDir, "static", "booklet", "styles.json"))
	for i := range Modules {
		if Modules[i].Name == name {
			return &Modules[i]
		}
	}
	return nil
}
