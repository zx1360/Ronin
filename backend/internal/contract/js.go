package contract

import (
	"fmt"
	"strings"
)

const jsHeader = "// 由 backend/cmd/route_export 生成，请勿手改。\n" +
	"// 重新生成：cd backend && go run ./cmd/route_export\n" +
	"// 路由来自 gin 路由表，标识符由 cmd/route_export 生成。\n\n"

// RenderJS 产出 ops 网页端的端点模块（纯 ES module，无依赖）。
func (c *Contract) RenderJS() string {
	var b strings.Builder
	b.WriteString(jsHeader)
	b.WriteString("// 静态路径表：键是生成的路由标识符，值是 gin 风格路径模板。\n")
	b.WriteString("export const API = {\n")
	for _, ep := range c.Doc.Endpoints {
		fmt.Fprintf(&b, "  '%s': '%s',\n", ep.Identifier, ep.Path)
	}
	b.WriteString("};\n")

	builders := make([]Endpoint, 0, len(c.Doc.Endpoints))
	for _, ep := range c.Doc.Endpoints {
		if len(ep.Params) > 0 {
			builders = append(builders, ep)
		}
	}
	if len(builders) > 0 {
		b.WriteString("\n// 带路径参数的端点：返回已编码的完整路径。\n")
		for _, ep := range builders {
			b.WriteString("\n")
			fmt.Fprintf(&b, "/** %s %s */\n", ep.Method, ep.Path)
			names := make([]string, 0, len(ep.Params))
			for _, p := range ep.Params {
				names = append(names, p.Name)
			}
			fmt.Fprintf(&b, "export function %s(%s) {\n", ep.Identifier, strings.Join(names, ", "))
			fmt.Fprintf(&b, "  return `%s`;\n", jsPathTemplate(ep))
			b.WriteString("}\n")
		}
	}
	return b.String()
}

// jsPathTemplate 把 gin 的 :param / *param 换成模板字符串插值。
// 普通参数做 URL 编码；通配参数（*filepath）是路径片段，原样拼接。
func jsPathTemplate(ep Endpoint) string {
	var b strings.Builder
	rest := ep.Path
	for {
		idx := strings.IndexAny(rest, ":*")
		if idx < 0 || idx+1 >= len(rest) {
			b.WriteString(rest)
			return b.String()
		}
		b.WriteString(rest[:idx])
		rest = rest[idx:]
		marker := rest[0]
		end := 1
		for end < len(rest) && rest[end] != '/' {
			end++
		}
		name := camelSegment(rest[1:end])
		if name == "" {
			name = "value"
		}
		if marker == ':' {
			b.WriteString("${encodeURIComponent(" + name + ")}")
		} else {
			b.WriteString("${" + name + "}")
		}
		rest = rest[end:]
	}
}
