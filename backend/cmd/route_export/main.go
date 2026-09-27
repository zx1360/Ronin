package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"monarch/internal/config"
	"monarch/internal/contract"
	"monarch/internal/router"
)

type routeRef = contract.RouteRef

type routeSnapshot struct {
	GeneratedAt string     `json:"generated_at"`
	Routes      []routeRef `json:"routes"`
}

func main() {
	jsonOut := flag.String("json", filepath.Join("references", "api", "routes.json"), "path to output routes json")
	mdOut := flag.String("md", filepath.Join("references", "api", "routes.md"), "path to output routes markdown")
	contractOut := flag.String("contract", filepath.Join("references", "api", "contract.json"), "path to output the client contract json")
	// 客户端产物在 backend/ 之外，默认值按仓库根解析（可从 backend/ 直接跑）。
	dartOut := flag.String("dart", filepath.Join(workspaceRoot(), "frontend", "lib", "core", "api", "generated", "api_contract.dart"), "path to output the generated Dart contract")
	jsOut := flag.String("js", filepath.Join(workspaceRoot(), "ops", "js", "generated", "endpoints.js"), "path to output the generated JS endpoints module")
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
			Method: item.Method,
			Path:   item.Path,
		})
	}

	sort.Slice(routes, func(i, j int) bool {
		if routes[i].Path == routes[j].Path {
			return routes[i].Method < routes[j].Method
		}
		return routes[i].Path < routes[j].Path
	})

	generatedAt := time.Now().UTC().Format(time.RFC3339)
	snapshot := routeSnapshot{
		GeneratedAt: generatedAt,
		Routes:      routes,
	}

	if err := writeJSON(*jsonOut, snapshot); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write json: %v\n", err)
		os.Exit(1)
	}

	if err := writeMarkdown(*mdOut, snapshot); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write markdown: %v\n", err)
		os.Exit(1)
	}

	client, err := contract.Build(generatedAt, routes)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to build client contract: %v\n", err)
		os.Exit(1)
	}
	if err := writeContractJSON(*contractOut, client.Doc); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write contract json: %v\n", err)
		os.Exit(1)
	}
	if err := writeText(*dartOut, client.RenderDart()); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write dart contract: %v\n", err)
		os.Exit(1)
	}
	if err := writeText(*jsOut, client.RenderJS()); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write js endpoints: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("route snapshot written: %s, %s\n", *jsonOut, *mdOut)
	fmt.Printf("client contract written: %s (%d types, %d endpoints), %s, %s\n",
		*contractOut, len(client.Doc.Types), len(client.Doc.Endpoints), *dartOut, *jsOut)
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

func writeContractJSON(path string, doc contract.Document) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	return os.WriteFile(path, data, 0o644)
}

func writeText(path, content string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o644)
}

func writeMarkdown(path string, snapshot routeSnapshot) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	var b strings.Builder
	b.WriteString("# Route Snapshot\n\n")
	b.WriteString(fmt.Sprintf("- GeneratedAt: %s\n", snapshot.GeneratedAt))
	b.WriteString(fmt.Sprintf("- TotalRoutes: %d\n\n", len(snapshot.Routes)))
	b.WriteString("| Method | Path |\n")
	b.WriteString("| --- | --- |\n")
	for _, route := range snapshot.Routes {
		b.WriteString(fmt.Sprintf("| %s | %s |\n", route.Method, route.Path))
	}

	return os.WriteFile(path, []byte(b.String()), 0o644)
}
