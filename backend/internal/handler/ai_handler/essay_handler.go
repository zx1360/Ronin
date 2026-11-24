package ai_handler

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"monarch/internal/service/ai"
)

func EssaySuggestions(c *gin.Context) {
	e := engine(c)
	if e == nil {
		return
	}
	if !e.Config().Enabled {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "服务端未启用 AI"})
		return
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, chatMaxBodyBytes)
	var req struct {
		Model string `json:"model"`
		ai.EssaySuggestionInput
	}
	if !bindJSON(c, &req) {
		return
	}
	if strings.TrimSpace(req.Content) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "随笔正文为空"})
		return
	}
	modelName, err := e.NormalizeModel(req.Model)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx, cancel := context.WithTimeout(c.Request.Context(), 4*time.Minute)
	defer cancel()
	if ok, reason := e.OllamaProvider().Ready(ctx, modelName); !ok {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": reason})
		return
	}
	result, err := e.SuggestEssay(ctx, modelName, req.EssaySuggestionInput)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}
