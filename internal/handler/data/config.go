// data/config.go
package data

import (
	"path/filepath"
)

// ModuleConfig 定义了一个模块所需的所有配置信息
type ModuleConfig struct {
	Name     string // 模块名称，如 "user_profile", "product_catalog"
	JSONPath string // JSON数据文件的路径
	ImageDir string // 图片文件存储目录
}

// moduleConfigs 是一个全局注册表，存储了所有已定义的模块配置
// 键是 module_name (e.g., "module_a")，值是对应的 ModuleConfig
var moduleConfigs = make(map[string]ModuleConfig)

// InitModuleConfigs 初始化模块配置。在应用启动时调用。
func InitModuleConfigs() {
	// 定义所有支持的模块及其路径
	// 这里可以从配置文件、数据库或直接在代码中定义
	modules := []ModuleConfig{
		{
			Name:     "module_a",
			JSONPath: filepath.Join("static", "modules", "module_a", "data.json"),
			ImageDir: filepath.Join("static", "modules", "module_a", "images"),
		},
		{
			Name:     "module_b",
			JSONPath: filepath.Join("static", "modules", "module_b", "data.json"),
			ImageDir: filepath.Join("static", "modules", "module_b", "images"),
		},
		// 在这里添加更多模块...
	}

	// 将模块配置加载到 map 中
	for _, m := range modules {
		moduleConfigs[m.Name] = m
	}
}

// GetModuleConfig 根据 moduleName 获取对应的配置
// 如果模块不存在，返回 (ModuleConfig{}, false)
func GetModuleConfig(moduleName string) (ModuleConfig, bool) {
	config, exists := moduleConfigs[moduleName]
	return config, exists
}
