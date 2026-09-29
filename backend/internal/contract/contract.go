// Package contract 由 gin 路由表推导两端客户端的端点契约：
// 路径常量（Dart 的 ApiPath）与带参数路径构造函数。
//
// 只生成端点。请求/响应模型由各端自己维护——生成它们需要一整套 Go 类型内省，
// 而业务侧实际使用的始终是手写模型（可带 json_serializable / Hive 等端上约束）。
package contract

// Contract 待渲染的端点契约。
type Contract struct {
	Endpoints []Endpoint
}

// Build 从路由清单构造契约。
func Build(routes []RouteRef) *Contract {
	return &Contract{Endpoints: BuildEndpoints(routes)}
}
