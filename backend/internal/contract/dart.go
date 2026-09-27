package contract

import (
	"fmt"
	"strings"
)

const dartHeader = "// 由 backend/cmd/route_export 生成，请勿手改。\n" +
	"// 重新生成：cd backend && go run ./cmd/route_export\n" +
	"// 类型登记见 backend/internal/contract，路由来自 gin 路由表。\n" +
	"//\n" +
	"// 说明：时间（FlexTime / time.Time）与 uuid.UUID 一律保留 wire 上的字符串形态；\n" +
	"// json.RawMessage 映射为 Object?（不透明 JSON）；[]byte 映射为 base64 字符串。\n\n"

const dartHelpers = `/// 后端 JSON 字段容错读取：键缺失或类型不符时回落到空值，避免契约演进直接崩在解析上。
String _asString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return false;
}
`

// RenderDart 产出 frontend 侧的单一契约文件。
func (c *Contract) RenderDart() string {
	var b strings.Builder
	b.WriteString(dartHeader)
	b.WriteString("abstract final class ApiPath {\n")
	for _, ep := range c.Doc.Endpoints {
		fmt.Fprintf(&b, "  static const String %s = '%s';\n", ep.Identifier, ep.Path)
	}

	builders := make([]Endpoint, 0, len(c.Doc.Endpoints))
	for _, ep := range c.Doc.Endpoints {
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
	b.WriteString("}\n\n")

	for _, schema := range c.Schemas {
		b.WriteString(renderDartClass(schema))
		b.WriteString("\n")
	}
	b.WriteString(dartHelpers)
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

func renderDartClass(schema *structSchema) string {
	var b strings.Builder
	fmt.Fprintf(&b, "/// %s\n", schema.Doc.GoType)
	fmt.Fprintf(&b, "class %s {\n", schema.Doc.Name)

	fmt.Fprintf(&b, "  const %s({\n", schema.Doc.Name)
	for _, f := range schema.Fields {
		if f.DartNullable {
			fmt.Fprintf(&b, "    this.%s,\n", f.DartName)
			continue
		}
		fmt.Fprintf(&b, "    required this.%s,\n", f.DartName)
	}
	b.WriteString("  });\n\n")

	fmt.Fprintf(&b, "  factory %s.fromJson(Map<String, dynamic> json) {\n", schema.Doc.Name)
	fmt.Fprintf(&b, "    return %s(\n", schema.Doc.Name)
	for _, f := range schema.Fields {
		fmt.Fprintf(&b, "      %s: %s,\n", f.DartName, dartRead("json['"+f.JSON+"']", f.Desc, f.DartNullable))
	}
	b.WriteString("    );\n  }\n\n")

	for _, f := range schema.Fields {
		fmt.Fprintf(&b, "  final %s %s;\n", f.DartType, f.DartName)
	}

	b.WriteString("\n  Map<String, dynamic> toJson() {\n")
	b.WriteString("    return <String, dynamic>{\n")
	for _, f := range schema.Fields {
		fmt.Fprintf(&b, "      '%s': %s,\n", f.JSON, dartWrite(f))
	}
	b.WriteString("    };\n  }\n}\n")
	return b.String()
}

// dartRead 生成从 wire 值到 Dart 值的表达式，缺失/null 都能安全落地。
func dartRead(expr string, desc *typeDesc, nullable bool) string {
	switch desc.Kind {
	case kindJSON:
		return expr
	case kindStruct:
		if nullable {
			return fmt.Sprintf("%s == null ? null : %s.fromJson(%s as Map<String, dynamic>)", expr, desc.Nested, expr)
		}
		return fmt.Sprintf("%s.fromJson((%s as Map<String, dynamic>?) ?? const <String, dynamic>{})", desc.Nested, expr)
	case kindList:
		element := dartRead("e", desc.Element, desc.Element.Nullable)
		if nullable {
			return fmt.Sprintf("%s == null ? null : (%s as List<dynamic>).map((e) => %s).toList()", expr, expr, element)
		}
		return fmt.Sprintf("(%s as List<dynamic>? ?? const <dynamic>[]).map((e) => %s).toList()", expr, element)
	case kindMap:
		value := dartRead("v", desc.Value, desc.Value.Nullable)
		if nullable {
			return fmt.Sprintf("%s == null ? null : (%s as Map<String, dynamic>).map((k, v) => MapEntry(k, %s))", expr, expr, value)
		}
		return fmt.Sprintf("(%s as Map<String, dynamic>? ?? const <String, dynamic>{}).map((k, v) => MapEntry(k, %s))", expr, value)
	}

	var core string
	switch desc.Kind {
	case kindInt:
		core = fmt.Sprintf("_asInt(%s)", expr)
	case kindDouble:
		core = fmt.Sprintf("_asDouble(%s)", expr)
	case kindBool:
		core = fmt.Sprintf("_asBool(%s)", expr)
	default: // string / uuid / time
		core = fmt.Sprintf("_asString(%s)", expr)
	}
	if nullable {
		return fmt.Sprintf("%s == null ? null : %s", expr, core)
	}
	return core
}

// dartWrite 生成 toJson 里的取值表达式。
func dartWrite(f fieldInfo) string {
	desc := f.Desc
	switch desc.Kind {
	case kindStruct:
		if f.DartNullable {
			return f.DartName + "?.toJson()"
		}
		return f.DartName + ".toJson()"
	case kindList:
		if desc.Element.Kind != kindStruct {
			return f.DartName
		}
		item := "e.toJson()"
		if desc.Element.Nullable {
			item = "e?.toJson()"
		}
		if f.DartNullable {
			return fmt.Sprintf("%s?.map((e) => %s).toList()", f.DartName, item)
		}
		return fmt.Sprintf("%s.map((e) => %s).toList()", f.DartName, item)
	default:
		return f.DartName
	}
}
