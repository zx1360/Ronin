package contract

// Field 契约里一个字段的客户端视图。
//
//	name     Go 字段名（取自反射，便于与源码对照）
//	json     wire 上的键名（json tag）
//	nullable wire 上可能为 null（Go 侧是指针或 json.RawMessage）
//	optional json tag 带 omitempty，键可能整个缺失
//
// Dart 侧的可空后缀 = nullable || optional（缺失与 null 都按可空处理）。
type Field struct {
	Name     string `json:"name"`
	JSON     string `json:"json"`
	GoType   string `json:"go_type"`
	DartType string `json:"dart_type"`
	TSType   string `json:"ts_type"`
	Nullable bool   `json:"nullable"`
	List     bool   `json:"list"`
	Optional bool   `json:"optional"`
}

// TypeDoc 一个客户端类型。
type TypeDoc struct {
	Name   string  `json:"name"`
	GoType string  `json:"go_type"`
	Fields []Field `json:"fields"`
}

// Document 是 contract.json 的内容。
type Document struct {
	GeneratedAt string     `json:"generated_at"`
	Routes      []RouteRef `json:"routes"`
	Types       []TypeDoc  `json:"types"`
	Endpoints   []Endpoint `json:"endpoints"`
}

// Contract 是生成结果：可序列化的 Document + 生成代码所需的结构体描述。
type Contract struct {
	Doc     Document
	Schemas []*structSchema
}

// Build 解析登记表与路由表，产出完整契约。
func Build(generatedAt string, routes []RouteRef) (*Contract, error) {
	b := newBuilder()
	for _, named := range Types() {
		if err := b.register(named); err != nil {
			return nil, err
		}
	}

	schemas, err := b.build()
	if err != nil {
		return nil, err
	}

	if routes == nil {
		routes = []RouteRef{}
	}
	doc := Document{
		GeneratedAt: generatedAt,
		Routes:      routes,
		Types:       make([]TypeDoc, 0, len(schemas)),
		Endpoints:   BuildEndpoints(routes),
	}
	for _, schema := range schemas {
		doc.Types = append(doc.Types, schema.Doc)
	}
	return &Contract{Doc: doc, Schemas: schemas}, nil
}
