package contract

import (
	"encoding/json"
	"fmt"
	"reflect"
	"strings"
	"time"

	"github.com/google/uuid"

	"monarch/internal/model"
)

// 客户端类型种类。生成器据此决定 Dart 读/写表达式。
const (
	kindString = "string"
	kindInt    = "int"
	kindDouble = "double"
	kindBool   = "bool"
	kindTime   = "time"
	kindUUID   = "uuid"
	kindJSON   = "json"
	kindStruct = "struct"
	kindMap    = "map"
	kindList   = "list"
)

// typeDesc 是对一个 Go 类型的客户端映射结果。
type typeDesc struct {
	Kind     string // kind* 之一
	GoType   string // Go 侧类型写法，如 "uuid.UUID" / "[]model.MediaAsset"
	DartType string // 不含可空后缀的 Dart 类型
	TSType   string
	Nullable bool      // 指针 / 可空 JSON（wire 上可能是 null）
	Element  *typeDesc // Kind == kindList
	Value    *typeDesc // Kind == kindMap
	Nested   string    // Kind == kindStruct 时的客户端类型名
}

// fieldInfo 是字段的对外描述 + 生成代码所需的类型信息。
type fieldInfo struct {
	Field
	Desc         *typeDesc
	DartName     string
	DartNullable bool // Desc.Nullable || Optional
}

// structSchema 一个已解析的结构体类型。
type structSchema struct {
	Doc    TypeDoc
	Fields []fieldInfo
}

// builder 负责扫描注册表、递归发现嵌套结构体并把每个字段映射到两端类型。
type builder struct {
	types   map[string]reflect.Type
	names   map[string]string
	order   []string
	schemas map[string]*structSchema
	used    map[string]string // 客户端名 -> 类型键，用于碰撞检测
}

var (
	uuidType       = reflect.TypeOf(uuid.UUID{})
	timeType       = reflect.TypeOf(time.Time{})
	rawMessageType = reflect.TypeOf(json.RawMessage(nil))
	flexTimeType   = reflect.TypeOf(model.FlexTime{})
	flexYearType   = reflect.TypeOf(model.FlexYear(0))
)

func typeKey(t reflect.Type) string {
	if t.Name() == "" {
		return t.String()
	}
	return t.PkgPath() + "." + t.Name()
}

// goTypeString 渲染 Go 类型，并把 []uint8 显示成更易读的 []byte。
func goTypeString(t reflect.Type) string {
	return strings.ReplaceAll(t.String(), "[]uint8", "[]byte")
}

func newBuilder() *builder {
	return &builder{
		types:   map[string]reflect.Type{},
		names:   map[string]string{},
		schemas: map[string]*structSchema{},
		used:    map[string]string{},
	}
}

// register 登记一个顶层类型；名称由登记表显式给出，避免客户端命名靠猜。
func (b *builder) register(nt NamedType) error {
	t := reflect.TypeOf(nt.Type)
	if t == nil {
		return fmt.Errorf("契约类型 %s 的零值实例为 nil", nt.Name)
	}
	for t.Kind() == reflect.Ptr {
		t = t.Elem()
	}
	if t.Kind() != reflect.Struct {
		return fmt.Errorf("契约类型 %s 必须是结构体，实际为 %s", nt.Name, t.Kind())
	}
	key := typeKey(t)
	if existing, ok := b.names[key]; ok {
		return fmt.Errorf("契约类型 %s 重复登记（已登记为 %s）", nt.Name, existing)
	}
	name := nt.Name
	if name == "" {
		name = t.Name()
	}
	if owner, ok := b.used[name]; ok && owner != key {
		return fmt.Errorf("契约类型名 %s 已被 %s 占用", name, owner)
	}
	b.used[name] = key
	b.names[key] = name
	b.types[key] = t
	b.order = append(b.order, key)
	return nil
}

// ensure 为嵌套结构体分配客户端类型名，并把它加入待展开队列。
func (b *builder) ensure(t reflect.Type) string {
	key := typeKey(t)
	if name, ok := b.names[key]; ok {
		return name
	}
	name := b.uniqueName(t)
	b.names[key] = name
	b.types[key] = t
	b.order = append(b.order, key)
	return name
}

// uniqueName 生成不与既有客户端类型冲突的名字；冲突时加包名前缀，再冲突加序号。
func (b *builder) uniqueName(t reflect.Type) string {
	base := t.Name()
	if base == "" {
		base = "Anonymous"
	}
	if _, taken := b.used[base]; !taken {
		b.used[base] = typeKey(t)
		return base
	}
	pkg := t.PkgPath()
	if idx := strings.LastIndex(pkg, "/"); idx >= 0 {
		pkg = pkg[idx+1:]
	}
	prefixed := strings.ToUpper(pkg[:1]) + pkg[1:] + base
	if _, taken := b.used[prefixed]; !taken {
		b.used[prefixed] = typeKey(t)
		return prefixed
	}
	for i := 2; ; i++ {
		candidate := fmt.Sprintf("%s%d", prefixed, i)
		if _, taken := b.used[candidate]; !taken {
			b.used[candidate] = typeKey(t)
			return candidate
		}
	}
}

// build 展开全部类型（含递归发现的嵌套结构体）。
func (b *builder) build() ([]*structSchema, error) {
	for i := 0; i < len(b.order); i++ {
		key := b.order[i]
		if _, done := b.schemas[key]; done {
			continue
		}
		t := b.types[key]
		fields, err := b.fieldsOf(t, map[string]bool{key: true})
		if err != nil {
			return nil, fmt.Errorf("解析类型 %s 失败: %w", b.names[key], err)
		}
		doc := TypeDoc{
			Name:   b.names[key],
			GoType: goTypeString(t),
			Fields: make([]Field, 0, len(fields)),
		}
		for _, f := range fields {
			doc.Fields = append(doc.Fields, f.Field)
		}
		b.schemas[key] = &structSchema{Doc: doc, Fields: fields}
	}

	out := make([]*structSchema, 0, len(b.order))
	for _, key := range b.order {
		if s, ok := b.schemas[key]; ok {
			out = append(out, s)
		}
	}
	return out, nil
}

// fieldsOf 把一个结构体摊平成客户端字段列表；匿名字段按 encoding/json 的规则内联。
func (b *builder) fieldsOf(t reflect.Type, stack map[string]bool) ([]fieldInfo, error) {
	fields := make([]fieldInfo, 0, t.NumField())
	for i := 0; i < t.NumField(); i++ {
		sf := t.Field(i)
		if sf.PkgPath != "" {
			continue // 未导出字段不参与 JSON
		}
		tag := sf.Tag.Get("json")
		name, optional, skip := parseJSONTag(tag, sf.Name)
		if skip {
			continue
		}

		if sf.Anonymous && tag == "" {
			base := sf.Type
			for base.Kind() == reflect.Ptr {
				base = base.Elem()
			}
			if base.Kind() == reflect.Struct && base.Name() != "" && !isSpecialStruct(base) {
				key := typeKey(base)
				if !stack[key] {
					stack[key] = true
					inlined, err := b.fieldsOf(base, stack)
					delete(stack, key)
					if err != nil {
						return nil, err
					}
					fields = append(fields, inlined...)
					continue
				}
			}
		}

		desc, err := b.mapType(sf.Type)
		if err != nil {
			return nil, fmt.Errorf("字段 %s: %w", sf.Name, err)
		}
		nullable := desc.Nullable || optional
		fields = append(fields, fieldInfo{
			Field: Field{
				Name:     sf.Name,
				JSON:     name,
				GoType:   desc.GoType,
				DartType: dartFieldType(desc, nullable),
				TSType:   desc.TSType,
				Nullable: desc.Nullable,
				List:     desc.Kind == kindList,
				Optional: optional,
			},
			Desc:         desc,
			DartNullable: nullable,
		})
	}
	return assignDartNames(fields), nil
}

// assignDartNames 给字段分配 Dart 侧名字（lowerCamelCase，避开保留字与重名）。
func assignDartNames(fields []fieldInfo) []fieldInfo {
	used := map[string]bool{}
	for i := range fields {
		name := dartIdentifier(lowerCamel(fields[i].Name))
		if name == "" {
			name = "field"
		}
		if used[name] {
			for n := 2; ; n++ {
				candidate := fmt.Sprintf("%s%d", name, n)
				if !used[candidate] {
					name = candidate
					break
				}
			}
		}
		used[name] = true
		fields[i].DartName = name
	}
	return fields
}

// mapType 把一个 reflect.Type 映射成客户端类型描述。
func (b *builder) mapType(t reflect.Type) (*typeDesc, error) {
	if t == nil {
		return &typeDesc{Kind: kindJSON, GoType: "any", DartType: "Object?", TSType: "unknown", Nullable: true}, nil
	}
	if t.Kind() == reflect.Ptr {
		inner, err := b.mapType(t.Elem())
		if err != nil {
			return nil, err
		}
		inner.Nullable = true
		inner.GoType = "*" + inner.GoType
		return inner, nil
	}
	switch t {
	case uuidType:
		return &typeDesc{Kind: kindUUID, GoType: "uuid.UUID", DartType: "String", TSType: "string"}, nil
	case flexTimeType, timeType:
		return &typeDesc{Kind: kindTime, GoType: goTypeString(t), DartType: "String", TSType: "string"}, nil
	case flexYearType:
		// FlexYear 自定义了 MarshalJSON，wire 上是字符串（兼容 Android）。
		return &typeDesc{Kind: kindString, GoType: goTypeString(t), DartType: "String", TSType: "string"}, nil
	case rawMessageType:
		return &typeDesc{Kind: kindJSON, GoType: "json.RawMessage", DartType: "Object?", TSType: "unknown", Nullable: true}, nil
	}

	switch t.Kind() {
	case reflect.Slice:
		if t.Elem().Kind() == reflect.Uint8 {
			// []byte 在 JSON 里是 base64 字符串。
			return &typeDesc{Kind: kindString, GoType: goTypeString(t), DartType: "String", TSType: "string"}, nil
		}
		elem, err := b.mapType(t.Elem())
		if err != nil {
			return nil, err
		}
		return &typeDesc{
			Kind:     kindList,
			GoType:   "[]" + elem.GoType,
			DartType: "List<" + dartFieldType(elem, elem.Nullable) + ">",
			TSType:   elem.TSType + "[]",
			Element:  elem,
		}, nil
	case reflect.Array:
		if t.Elem().Kind() == reflect.Uint8 {
			return &typeDesc{Kind: kindString, GoType: goTypeString(t), DartType: "String", TSType: "string"}, nil
		}
		elem, err := b.mapType(t.Elem())
		if err != nil {
			return nil, err
		}
		return &typeDesc{
			Kind:     kindList,
			GoType:   goTypeString(t),
			DartType: "List<" + dartFieldType(elem, elem.Nullable) + ">",
			TSType:   elem.TSType + "[]",
			Element:  elem,
		}, nil
	case reflect.Map:
		if t.Key().Kind() != reflect.String {
			return &typeDesc{Kind: kindMap, GoType: goTypeString(t), DartType: "Map<String, Object?>", TSType: "Record<string, unknown>"}, nil
		}
		value, err := b.mapType(t.Elem())
		if err != nil {
			return nil, err
		}
		return &typeDesc{
			Kind:     kindMap,
			GoType:   goTypeString(t),
			DartType: "Map<String, " + dartFieldType(value, value.Nullable) + ">",
			TSType:   "Record<string, " + value.TSType + ">",
			Value:    value,
		}, nil
	case reflect.Struct:
		name := b.ensure(t)
		return &typeDesc{Kind: kindStruct, GoType: goTypeString(t), DartType: name, TSType: name, Nested: name}, nil
	case reflect.String:
		return &typeDesc{Kind: kindString, GoType: goTypeString(t), DartType: "String", TSType: "string"}, nil
	case reflect.Bool:
		return &typeDesc{Kind: kindBool, GoType: goTypeString(t), DartType: "bool", TSType: "boolean"}, nil
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return &typeDesc{Kind: kindInt, GoType: goTypeString(t), DartType: "int", TSType: "number"}, nil
	case reflect.Float32, reflect.Float64:
		return &typeDesc{Kind: kindDouble, GoType: goTypeString(t), DartType: "double", TSType: "number"}, nil
	case reflect.Interface:
		return &typeDesc{Kind: kindJSON, GoType: goTypeString(t), DartType: "Object?", TSType: "unknown", Nullable: true}, nil
	default:
		return &typeDesc{Kind: kindJSON, GoType: goTypeString(t), DartType: "Object?", TSType: "unknown", Nullable: true}, nil
	}
}

// isSpecialStruct 报告该结构体是否已有专门的类型映射（不需要递归展开）。
func isSpecialStruct(t reflect.Type) bool {
	return t == timeType
}

// parseJSONTag 解析 json tag：name 是 wire 上的键名，optional 表示 omitempty。
func parseJSONTag(tag, goName string) (name string, optional bool, skip bool) {
	if tag == "-" {
		return "", false, true
	}
	if tag == "" {
		return goName, false, false
	}
	parts := strings.Split(tag, ",")
	name = parts[0]
	if name == "" {
		name = goName
	}
	for _, opt := range parts[1:] {
		if opt == "omitempty" {
			optional = true
		}
	}
	return name, optional, false
}

// dartFieldType 渲染 Dart 字段类型（含可空后缀）。
func dartFieldType(d *typeDesc, nullable bool) string {
	if nullable && !strings.HasSuffix(d.DartType, "?") {
		return d.DartType + "?"
	}
	return d.DartType
}
