package contract

import (
	"sort"
	"strconv"
	"strings"
)

// RouteRef 一条路由；与 references/api/routes.json 的条目一一对应。
type RouteRef struct {
	Method string `json:"method"`
	Path   string `json:"path"`
}

// pathBuilderSuffix 是 Dart 侧"带参路径构造函数"的后缀：
// 同一个类里 static const 与 static 方法不能同名，故构造函数必须另起名字。
const pathBuilderSuffix = "Path"

// PathBuilderName 返回某条带参路由在 Dart 侧的构造函数名。
func PathBuilderName(identifier string) string {
	return identifier + pathBuilderSuffix
}

// EndpointParam 路径参数（gin 的 :name 或 *name）。
type EndpointParam struct {
	Name     string `json:"name"`
	Wildcard bool   `json:"wildcard,omitempty"`
}

// Endpoint 一条带生成标识符的路由；客户端用标识符引用端点，不再手抄路径。
type Endpoint struct {
	Group      string          `json:"group"`
	Identifier string          `json:"identifier"`
	Method     string          `json:"method"`
	Path       string          `json:"path"`
	Params     []EndpointParam `json:"params,omitempty"`
}

// BuildEndpoints 给每条路由生成分组与标识符。结果按"分组 → 路径 → 方法"排序，
// 因此 endpoints 本身就是按 /API/ 之后第一段聚好的清单。
//
// 标识符 = 路径片段（含参数名）的 camelCase，如 GET /API/gallery/media -> galleryMedia；
// 重名时按"基础名 + HTTP 方法"消解（GET 先于 PATCH，因此 GET 保住基础名），
// 仍冲突则再追加序号，保证结果确定且唯一。
func BuildEndpoints(routes []RouteRef) []Endpoint {
	ordered := make([]RouteRef, len(routes))
	copy(ordered, routes)
	sort.SliceStable(ordered, func(i, j int) bool {
		gi, gj := pathGroup(ordered[i].Path), pathGroup(ordered[j].Path)
		if gi != gj {
			return gi < gj
		}
		if ordered[i].Path != ordered[j].Path {
			return ordered[i].Path < ordered[j].Path
		}
		return ordered[i].Method < ordered[j].Method
	})

	used := make(map[string]bool, len(ordered))
	out := make([]Endpoint, 0, len(ordered))

	for _, route := range ordered {
		segments, params := pathSegments(route.Path)
		base := camelJoin(segments)
		if base == "" {
			base = "root"
		}

		identifier := base
		if used[identifier] {
			identifier = base + methodSuffix(route.Method)
		}
		for n := 2; used[identifier]; n++ {
			identifier = base + methodSuffix(route.Method) + strconv.Itoa(n)
		}
		used[identifier] = true
		if len(params) > 0 {
			// Dart 里 const 与静态方法同名会编译失败，因此带参路由的构造器
			// 用 "<标识符>Path"，并在此预留该名字，避免被别的路由占用。
			used[identifier+pathBuilderSuffix] = true
		}

		out = append(out, Endpoint{
			Group:      pathGroup(route.Path),
			Identifier: identifier,
			Method:     route.Method,
			Path:       route.Path,
			Params:     params,
		})
	}
	return out
}

// pathGroup 取 /API/ 之后的第一个路径片段；非 API 路由取首个片段（"/" 归入 root）。
func pathGroup(path string) string {
	clean := strings.Trim(path, "/")
	if clean == "" {
		return "root"
	}
	parts := strings.Split(clean, "/")
	if strings.EqualFold(parts[0], "API") {
		if len(parts) < 2 {
			return "root"
		}
		return parts[1]
	}
	return parts[0]
}

// pathSegments 把路由拆成"标识符片段 + 路径参数"。
func pathSegments(path string) ([]string, []EndpointParam) {
	clean := strings.Trim(path, "/")
	if clean == "" {
		return []string{"root"}, nil
	}
	parts := strings.Split(clean, "/")
	if strings.EqualFold(parts[0], "API") {
		parts = parts[1:]
	}

	segments := make([]string, 0, len(parts))
	var params []EndpointParam
	for _, part := range parts {
		if part == "" {
			continue
		}
		wildcard := strings.HasPrefix(part, "*")
		raw := strings.TrimPrefix(strings.TrimPrefix(part, ":"), "*")
		name := camelSegment(raw)
		if name == "" {
			continue
		}
		segments = append(segments, name)
		if strings.HasPrefix(part, ":") || wildcard {
			params = append(params, EndpointParam{Name: name, Wildcard: wildcard})
		}
	}
	if len(segments) == 0 {
		segments = []string{"root"}
	}
	return segments, params
}
