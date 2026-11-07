package gallery_handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"monarch/internal/repository/gallery_repo"
)

func FetchLibrary(c *gin.Context) {
	id, err := gallery_repo.LibraryID(c.Request.Context())
	if err != nil {
		respondRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"library_id": id})
}

func CheckLibrary(c *gin.Context) {
	expected := c.Query("library_id")
	if expected == "" {
		return
	}
	id, err := gallery_repo.LibraryID(c.Request.Context())
	if err != nil {
		respondRepoError(c, err)
		c.Abort()
		return
	}
	if id != expected {
		c.AbortWithStatusJSON(http.StatusConflict, gin.H{"error": "当前服务器不是本机缓存所属的图库"})
	}
}
