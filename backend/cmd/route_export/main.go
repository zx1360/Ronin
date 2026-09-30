package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"monarch/internal/config"
	"monarch/internal/router"
)

// 契约快照是生成物：只含可从代码确定性导出的内容，不含时间戳等易变字段，
// 以便重复生成得到逐字节相同的结果（`generate_refs.ps1 -Check` 依赖这一点）。
type routeRef struct {
	Method string `json:"method"`
	Path   string `json:"path"`
	// Handler 处理后端函数全名，便于端上对照响应字段时直接定位实现
	Handler string `json:"handler"`
}

type routeSnapshot struct {
	Routes []routeRef `json:"routes"`
}

func main() {
	jsonOut := flag.String("json", filepath.Join("references", "generated", "api", "routes.json"), "path to output routes json")
	mdOut := flag.String("md", filepath.Join("references", "generated", "api", "routes.md"), "path to output routes markdown")
	flag.Parse()

	_ = config.Load()
	if config.AppConf.StaticDir == "" {
		config.AppConf.StaticDir = "static"
	}
	config.IsLocalMode = true

	r := router.SetupRouter()
	routeInfos := r.Routes()
	routes := make([]routeRef, 0, len(routeInfos))
	for _, item := range routeInfos {
		routes = append(routes, routeRef{
			Method:  item.Method,
			Path:    item.Path,
			Handler: item.Handler,
		})
	}

	sort.Slice(routes, func(i, j int) bool {
		if routes[i].Path == routes[j].Path {
			return routes[i].Method < routes[j].Method
		}
		return routes[i].Path < routes[j].Path
	})

	snapshot := routeSnapshot{Routes: routes}

	if err := writeJSON(*jsonOut, snapshot); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write json: %v\n", err)
		os.Exit(1)
	}

	if err := writeMarkdown(*mdOut, snapshot); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write markdown: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("route snapshot written: %s, %s\n", *jsonOut, *mdOut)
}

func writeJSON(path string, snapshot routeSnapshot) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(snapshot, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	return os.WriteFile(path, data, 0o644)
}

func writeMarkdown(path string, snapshot routeSnapshot) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	var b strings.Builder
	b.WriteString("# Route Snapshot\n\n")
	b.WriteString(fmt.Sprintf("- TotalRoutes: %d\n\n", len(snapshot.Routes)))
	b.WriteString("| Method | Path | Handler |\n")
	b.WriteString("| --- | --- | --- |\n")
	for _, route := range snapshot.Routes {
		b.WriteString(fmt.Sprintf("| %s | %s | `%s` |\n", route.Method, route.Path, route.Handler))
	}

	return os.WriteFile(path, []byte(b.String()), 0o644)
}
