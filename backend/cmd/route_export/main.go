package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"monarch/internal/config"
	"monarch/internal/contract"
	"monarch/internal/router"
)

func main() {
	// 客户端产物在 backend/ 之外，默认值按仓库根解析（可从 backend/ 直接跑）。
	dartOut := flag.String("dart", filepath.Join(workspaceRoot(), "frontend", "lib", "core", "api", "generated", "api_contract.dart"), "path to output the generated Dart contract")
	jsOut := flag.String("js", filepath.Join(workspaceRoot(), "ops", "js", "generated", "endpoints.js"), "path to output the generated JS endpoints module")
	flag.Parse()

	_ = config.Load()
	if config.AppConf.StaticDir == "" {
		config.AppConf.StaticDir = "static"
	}
	config.IsLocalMode = true

	routeInfos := router.SetupRouter().Routes()
	routes := make([]contract.RouteRef, 0, len(routeInfos))
	for _, item := range routeInfos {
		routes = append(routes, contract.RouteRef{Method: item.Method, Path: item.Path})
	}
	sort.Slice(routes, func(i, j int) bool {
		if routes[i].Path == routes[j].Path {
			return routes[i].Method < routes[j].Method
		}
		return routes[i].Path < routes[j].Path
	})

	client := contract.Build(routes)
	if err := writeText(*dartOut, client.RenderDart()); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write dart contract: %v\n", err)
		os.Exit(1)
	}
	if err := writeText(*jsOut, client.RenderJS()); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write js endpoints: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("client contract written: %d endpoints, %s, %s\n", len(client.Endpoints), *dartOut, *jsOut)
}

// workspaceRoot 定位仓库根（同时含 backend/ 与 frontend/ 的目录），
// 供 -dart / -js 的默认输出路径使用；从 backend/ 运行时即其父目录。
func workspaceRoot() string {
	cwd, err := os.Getwd()
	if err != nil {
		return ".."
	}
	dir := cwd
	for i := 0; i < 8; i++ {
		if isDir(filepath.Join(dir, "backend")) && isDir(filepath.Join(dir, "frontend")) {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return filepath.Dir(cwd)
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func writeText(path, content string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o644)
}
