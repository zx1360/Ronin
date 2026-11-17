package data_handler

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"monarch/internal/service/db"
)

func GetTraceBackup(c *gin.Context) {
	var revision int64
	var snapshot json.RawMessage
	var raw string
	err := db.Read().QueryRowContext(c.Request.Context(),
		"SELECT revision, snapshot FROM trace_backup WHERE id = 1").Scan(&revision, &raw)
	if err == nil {
		snapshot = json.RawMessage(raw)
	} else if !errors.Is(err, sql.ErrNoRows) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "读取时迹备份失败"})
		return
	}
	c.Header("Cache-Control", "no-store")
	c.JSON(http.StatusOK, gin.H{"revision": revision, "snapshot": snapshot})
}

func PutTraceBackup(c *gin.Context) {
	var request struct {
		Revision *int64          `json:"revision"`
		Snapshot json.RawMessage `json:"snapshot"`
	}
	var snapshot struct {
		Version  int               `json:"format_version"`
		Scenes   []json.RawMessage `json:"scenes"`
		Items    []json.RawMessage `json:"items"`
		Tags     []json.RawMessage `json:"tags"`
		Sessions []json.RawMessage `json:"sessions"`
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 32<<20)
	if c.ShouldBindJSON(&request) != nil || request.Revision == nil || *request.Revision < 0 ||
		json.Unmarshal(request.Snapshot, &snapshot) != nil || snapshot.Version != 1 ||
		snapshot.Scenes == nil || snapshot.Items == nil || snapshot.Tags == nil || snapshot.Sessions == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "时迹备份或修订号无效"})
		return
	}
	base := *request.Revision
	ctx := c.Request.Context()
	var result sql.Result
	var err error
	if base == 0 {
		result, err = db.Exec(ctx, `INSERT INTO trace_backup (id, revision, snapshot)
			VALUES (1, 1, ?) ON CONFLICT (id) DO NOTHING`, string(request.Snapshot))
	} else {
		result, err = db.Exec(ctx, `UPDATE trace_backup SET revision = revision + 1, snapshot = ?
			WHERE id = 1 AND revision = ?`, string(request.Snapshot), base)
	}
	if err == nil {
		var updated int64
		updated, err = result.RowsAffected()
		if err == nil && updated == 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "时迹备份已更新，请重新合并"})
			return
		}
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "写入时迹备份失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"revision": base + 1})
}
