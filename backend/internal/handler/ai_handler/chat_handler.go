package ai_handler

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	"monarch/internal/service/ai"
)

// 请求体上限：对话允许内联图片，但必须挡住畸形/超大请求。
const (
	chatMaxBodyBytes  = 32 << 20 // 32MB
	chatMaxMessages   = 100
	chatMaxTextRunes  = 32000
	chatMaxImageBytes = 8 << 20 // 单图（base64 解码后）
	// 模型驻留时长上限（24 小时），与客户端设置页的取值范围一致
	chatMaxKeepAliveSeconds = 86400
)

// chatTuning 一次流式对话的可调项，/chat 与 /review 共用。
type chatTuning struct {
	// Model 为空表示使用当前生效的 VLM 模型；只接受 默认/备选 两个候选
	Model string `json:"model"`
	// 以下为可选项，缺省时沿用服务端配置。
	NumCtx           int      `json:"num_ctx"`
	Think            bool     `json:"think"`
	Temperature      *float64 `json:"temperature"`
	KeepAliveSeconds *int     `json:"keep_alive_seconds"`
}

// resolve 校验可调项并换算为引擎选项，返回本次实际使用的模型名。
func (t chatTuning) resolve(e *ai.Engine) (string, ai.ChatOptions, error) {
	options := ai.ChatOptions{
		NumCtx:      t.NumCtx,
		Think:       t.Think,
		Temperature: -1, // 负值 = 取服务端默认温度
		// 负值 = 取服务端默认驻留时长（0 是合法值：回答完立即卸载）
		KeepAliveSeconds: -1,
	}
	if t.Temperature != nil {
		options.Temperature = *t.Temperature
	}
	if t.KeepAliveSeconds != nil {
		if *t.KeepAliveSeconds < 0 || *t.KeepAliveSeconds > chatMaxKeepAliveSeconds {
			return "", options, errors.New("keep_alive_seconds 超出范围")
		}
		options.KeepAliveSeconds = *t.KeepAliveSeconds
	}

	modelName := strings.TrimSpace(t.Model)
	if modelName == "" {
		return e.VLMModel(), options, nil
	}
	if modelName != e.VLMModel() && modelName != e.VLMAltModel() {
		// 只接受两个候选（默认 / 无审查版），避免客户端塞进任意模型名
		return "", options, errors.New("未知模型: " + modelName)
	}
	return modelName, options, nil
}

// chatRequest POST /API/ai/chat 请求体。
type chatRequest struct {
	Messages []chatMessage `json:"messages"`
	chatTuning
}

// chatMessage 一条消息。图片可以是库内媒体（media_ids）或内联 base64（images）。
type chatMessage struct {
	Role     string   `json:"role"`
	Content  string   `json:"content"`
	MediaIDs []string `json:"media_ids"`
	Images   []string `json:"images"`
}

// Chat 处理 POST /API/ai/chat：流式多轮对话。
//
// 响应为 NDJSON（每行一个事件）：`{"type":"thinking"|"delta"|"done"|"error",...}`。
// 不做一次性返回：思考链与回答都要逐字出现，否则首字节要等几十秒。
// 该接口不读写 ai schema，只依赖 Ollama 与 gallery 媒体文件。
func Chat(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, chatMaxBodyBytes)
	var req chatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求体解析失败: " + err.Error()})
		return
	}
	if len(req.Messages) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "messages 不能为空"})
		return
	}
	if len(req.Messages) > chatMaxMessages {
		c.JSON(http.StatusBadRequest, gin.H{"error": "消息条数超出上限"})
		return
	}

	// 先把全部媒体 ID 一次解析为 base64，避免逐条查询。
	mediaIDs := collectMediaIDs(req.Messages)
	var resolved map[string]string
	if len(mediaIDs) > 0 {
		var missing []string
		var err error
		resolved, missing, err = e.ResolveChatImages(mediaIDs)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if len(missing) > 0 {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "以下媒体文件不可用: " + strings.Join(missing, ", "),
			})
			return
		}
	}

	messages := make([]ai.ChatMessage, 0, len(req.Messages))
	for i, item := range req.Messages {
		position := strconv.Itoa(i + 1)
		role := strings.TrimSpace(item.Role)
		if role != "system" && role != "user" && role != "assistant" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "第 " + position + " 条消息的 role 非法"})
			return
		}
		if utf8.RuneCountInString(item.Content) > chatMaxTextRunes {
			c.JSON(http.StatusBadRequest, gin.H{"error": "第 " + position + " 条消息内容过长"})
			return
		}

		images := make([]string, 0, len(item.MediaIDs)+len(item.Images))
		for _, id := range item.MediaIDs {
			data, ok := resolved[strings.TrimSpace(id)]
			if !ok {
				c.JSON(http.StatusBadRequest, gin.H{"error": "媒体不可用: " + id})
				return
			}
			images = append(images, data)
		}
		for _, raw := range item.Images {
			raw = strings.TrimSpace(raw)
			// 手机端一般直接给裸 base64；容忍误带的 data URL 前缀。
			if idx := strings.Index(raw, ","); idx >= 0 && strings.HasPrefix(raw, "data:") {
				raw = raw[idx+1:]
			}
			if raw == "" {
				continue
			}
			if base64.StdEncoding.DecodedLen(len(raw)) > chatMaxImageBytes {
				c.JSON(http.StatusBadRequest, gin.H{"error": "第 " + position + " 条消息的图片过大"})
				return
			}
			images = append(images, raw)
		}

		if strings.TrimSpace(item.Content) == "" && len(images) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "第 " + position + " 条消息为空"})
			return
		}
		messages = append(messages, ai.ChatMessage{
			Role:    role,
			Content: item.Content,
			Images:  images,
		})
	}

	modelName, options, err := req.chatTuning.resolve(e)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	streamChat(c, e, "对话", modelName, options, messages)
}

// streamChat 以 NDJSON 流式承接一次对话，/chat 与 /review 共用。
//
// 调用方负责参数校验与消息组装；prelude 是正文之前先下发的事件（如回顾的确定性统计）。
// 模型未就绪时以 503 返回 JSON，因此必须发生在写出流式响应头之前。
func streamChat(c *gin.Context, e *ai.Engine, purpose, modelName string, options ai.ChatOptions, messages []ai.ChatMessage, prelude ...ai.ChatEvent) {
	if ok, reason := e.OllamaProvider().Ready(c.Request.Context(), modelName); !ok {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": reason})
		return
	}

	c.Header("Content-Type", "application/x-ndjson; charset=utf-8")
	c.Header("Cache-Control", "no-cache")
	c.Header("X-Accel-Buffering", "no")
	writer := c.Writer

	write := func(event ai.ChatEvent) error {
		raw, err := json.Marshal(event)
		if err != nil {
			return err
		}
		if _, err := writer.Write(append(raw, '\n')); err != nil {
			return err
		}
		writer.Flush()
		return nil
	}
	for _, event := range prelude {
		if err := write(event); err != nil {
			return
		}
	}

	// 前台优先级：本机同时只跑一个模型，需要切换时抢占后台标注并释放其显存。
	lease := e.UseModel(c.Request.Context(), modelName, purpose, ai.ModelForeground)
	defer lease.Release()
	if lease.Notice != "" {
		_ = write(ai.ChatEvent{Type: "notice", Content: lease.Notice})
	}

	// 客户端断开时 ctx 会取消，进而中断对 Ollama 的请求，避免白跑推理。
	err := e.OllamaProvider().Chat(lease.Context(), modelName, messages, options, write)
	switch {
	case err == nil:
	case lease.AbortReason() != "":
		// 被另一个模型抢占：如实告知原因，客户端可把它显示成"已中断"而不是报错
		_ = write(ai.ChatEvent{Type: "aborted", Error: lease.AbortReason()})
	case lease.Context().Err() != nil:
		// 客户端断开：没人接收，无需再写事件
	default:
		_ = write(ai.ChatEvent{Type: "error", Error: err.Error()})
	}
}

// collectMediaIDs 汇总所有消息引用到的媒体 ID（去重后保持顺序）。
func collectMediaIDs(messages []chatMessage) []string {
	seen := map[string]bool{}
	var ids []string
	for _, msg := range messages {
		for _, raw := range msg.MediaIDs {
			id := strings.TrimSpace(raw)
			if id == "" || seen[id] {
				continue
			}
			seen[id] = true
			ids = append(ids, id)
		}
	}
	return ids
}
