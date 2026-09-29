package contract

import (
	"fmt"
	"strings"
)

const dartHeader = "// 由 backend/cmd/route_export 生成，请勿手改。\n" +
	"// 重新生成：cd backend && go run ./cmd/route_export\n" +
	"// 路由来自 gin 路由表；业务模型不在此文件，见各 feature 的 models/。\n\n"

// RenderDart 产出 frontend 侧的端点契约文件。
func (c *Contract) RenderDart() string {
	var b strings.Builder
	b.WriteString(dartHeader)
	b.WriteString("abstract final class ApiPath {\n")
	for _, ep := range c.Endpoints {
		fmt.Fprintf(&b, "  static const String %s = '%s';\n", ep.Identifier, ep.Path)
	}

	builders := make([]Endpoint, 0, len(c.Endpoints))
	for _, ep := range c.Endpoints {
		if len(ep.Params) > 0 {
			builders = append(builders, ep)
		}
	}
	if len(builders) > 0 {
		b.WriteString("\n")
		for i, ep := range builders {
			if i > 0 {
				b.WriteString("\n")
			}
			writeDartBuilder(&b, ep)
		}
	}
	b.WriteString("}\n")
	return b.String()
}

func writeDartBuilder(b *strings.Builder, ep Endpoint) {
	params := make([]string, 0, len(ep.Params))
	for _, p := range ep.Params {
		params = append(params, "String "+p.Name)
	}
	fmt.Fprintf(b, "  /// %s %s\n", ep.Method, ep.Path)
	fmt.Fprintf(b, "  static String %s(%s) {\n", PathBuilderName(ep.Identifier), strings.Join(params, ", "))
	fmt.Fprintf(b, "    return '%s';\n", dartPathTemplate(ep))
	b.WriteString("  }\n")
}

// dartPathTemplate 把 gin 的 :param / *param 换成 Dart 插值。
func dartPathTemplate(ep Endpoint) string {
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
			b.WriteString("${Uri.encodeComponent(" + name + ")}")
		} else {
			// 通配参数是路径片段，原样拼接；简单标识符不必加花括号。
			b.WriteString("$" + name)
		}
		rest = rest[end:]
	}
}
