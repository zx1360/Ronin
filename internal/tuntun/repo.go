package tuntun

import (
	"context"
	"fmt"

	"gizmos/internal/service/db"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo 数据库操作接口
type Repo interface {
	InitSchema() error                                        // 初始化表结构
	CreateMediaGroup(group *MediaGroup) error                 // 创建媒体组
	CreateTag(tag *Tag) error                                 // 创建标签
	CreateGroupTag(gt *GroupTag) error                        // 创建组-标签关联
	CreateMediaFile(file *MediaFile) error                    // 创建媒体文件记录
	GetMediaGroupByID(groupID uuid.UUID) (*MediaGroup, error) // 查询媒体组
	GetTagByName(name string) (*Tag, error)                   // 按名称查询标签
	IsFileExists(filePath string) (bool, error)               // 检查文件是否已存在
}

// repo 实现Repo接口
type repo struct {
	pool *pgxpool.Pool
}

// NewRepo 创建Repo实例
func NewRepo(pool *pgxpool.Pool) Repo {
	return &repo{pool: pool}
}

// InitSchema 初始化表结构
func (r *repo) InitSchema() error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return initSchema(ctx, r.pool)
}

func initSchema(ctx context.Context, pool *pgxpool.Pool) error {
	// 创建tuntun模式
	createSchemaSQL := `CREATE SCHEMA IF NOT EXISTS tuntun;`
	if _, err := pool.Exec(ctx, createSchemaSQL); err != nil {
		return fmt.Errorf("create schema failed: %w", err)
	}

	// 创建media_groups表
	createMediaGroupsSQL := `
	CREATE TABLE IF NOT EXISTS tuntun.media_groups (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		remark TEXT
	);`
	if _, err := pool.Exec(ctx, createMediaGroupsSQL); err != nil {
		return fmt.Errorf("create media_groups failed: %w", err)
	}

	// 创建tags表
	createTagsSQL := `
	CREATE TABLE IF NOT EXISTS tuntun.tags (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		name VARCHAR(50) NOT NULL UNIQUE,
		description TEXT
	);`
	if _, err := pool.Exec(ctx, createTagsSQL); err != nil {
		return fmt.Errorf("create tags failed: %w", err)
	}

	// 创建group_tags表
	createGroupTagsSQL := `
	CREATE TABLE IF NOT EXISTS tuntun.group_tags (
		group_id UUID NOT NULL,
		tag_id UUID NOT NULL,
		PRIMARY KEY (group_id, tag_id),
		CONSTRAINT fk_group_tags_group FOREIGN KEY (group_id) REFERENCES tuntun.media_groups(id) ON DELETE CASCADE,
		CONSTRAINT fk_group_tags_tag FOREIGN KEY (tag_id) REFERENCES tuntun.tags(id) ON DELETE CASCADE
	);`
	if _, err := pool.Exec(ctx, createGroupTagsSQL); err != nil {
		return fmt.Errorf("create group_tags failed: %w", err)
	}

	// 创建media_files表
	createMediaFilesSQL := `
	CREATE TABLE IF NOT EXISTS tuntun.media_files (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		file_path TEXT NOT NULL UNIQUE,
		ext VARCHAR(10) NOT NULL,
		file_size BIGINT NOT NULL,
		create_time BIGINT NOT NULL,
		date_range VARCHAR(7) NOT NULL,
		mime_type VARCHAR(50) NOT NULL,
		group_id UUID NOT NULL,
		CONSTRAINT fk_media_files_group FOREIGN KEY (group_id) REFERENCES tuntun.media_groups(id) ON DELETE RESTRICT
	);`
	if _, err := pool.Exec(ctx, createMediaFilesSQL); err != nil {
		return fmt.Errorf("create media_files failed: %w", err)
	}

	return nil
}

// CreateMediaGroup 创建媒体组
func (r *repo) CreateMediaGroup(group *MediaGroup) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return createMediaGroup(ctx, r.pool, group)
}

func createMediaGroup(ctx context.Context, pool *pgxpool.Pool, group *MediaGroup) error {
	if group.ID == uuid.Nil {
		group.ID = uuid.New()
	}

	sql := `INSERT INTO tuntun.media_groups (id, remark) VALUES ($1, $2)`
	_, err := pool.Exec(ctx, sql, group.ID, group.Remark)
	if err != nil {
		return fmt.Errorf("insert media group failed: %w", err)
	}
	return nil
}

// CreateTag 创建标签
func (r *repo) CreateTag(tag *Tag) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return createTag(ctx, r.pool, tag)
}

func createTag(ctx context.Context, pool *pgxpool.Pool, tag *Tag) error {
	if tag.ID == uuid.Nil {
		tag.ID = uuid.New()
	}

	sql := `INSERT INTO tuntun.tags (id, name, description) VALUES ($1, $2, $3) ON CONFLICT (name) DO NOTHING`
	_, err := pool.Exec(ctx, sql, tag.ID, tag.Name, tag.Description)
	if err != nil {
		return fmt.Errorf("insert tag failed: %w", err)
	}
	return nil
}

// CreateGroupTag 创建组-标签关联
func (r *repo) CreateGroupTag(gt *GroupTag) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return createGroupTag(ctx, r.pool, gt)
}

func createGroupTag(ctx context.Context, pool *pgxpool.Pool, gt *GroupTag) error {
	sql := `INSERT INTO tuntun.group_tags (group_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`
	_, err := pool.Exec(ctx, sql, gt.GroupID, gt.TagID)
	if err != nil {
		return fmt.Errorf("insert group tag failed: %w", err)
	}
	return nil
}

// CreateMediaFile 创建媒体文件记录
func (r *repo) CreateMediaFile(file *MediaFile) error {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return createMediaFile(ctx, r.pool, file)
}

func createMediaFile(ctx context.Context, pool *pgxpool.Pool, file *MediaFile) error {
	if file.ID == uuid.Nil {
		file.ID = uuid.New()
	}

	sql := `INSERT INTO tuntun.media_files 
	(file_path, ext, file_size, create_time, date_range, mime_type, group_id, id)
	VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`

	_, err := pool.Exec(
		ctx,
		sql,
		file.FilePath,
		file.Ext,
		file.FileSize,
		file.CreateTime,
		file.DateRange,
		file.MimeType,
		file.GroupID,
		file.ID,
	)
	if err != nil {
		return fmt.Errorf("insert media file failed: %w", err)
	}
	return nil
}

// GetMediaGroupByID 查询媒体组
func (r *repo) GetMediaGroupByID(groupID uuid.UUID) (*MediaGroup, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getMediaGroupByID(ctx, r.pool, groupID)
}

func getMediaGroupByID(ctx context.Context, pool *pgxpool.Pool, groupID uuid.UUID) (*MediaGroup, error) {
	group := &MediaGroup{}
	sql := `SELECT id, remark FROM tuntun.media_groups WHERE id = $1`
	err := pool.QueryRow(ctx, sql, groupID).Scan(&group.ID, &group.Remark)
	if err != nil {
		return nil, fmt.Errorf("query media group failed: %w", err)
	}
	return group, nil
}

// GetTagByName 按名称查询标签
func (r *repo) GetTagByName(name string) (*Tag, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return getTagByName(ctx, r.pool, name)
}

func getTagByName(ctx context.Context, pool *pgxpool.Pool, name string) (*Tag, error) {
	tag := &Tag{}
	sql := `SELECT id, name, description FROM tuntun.tags WHERE name = $1`
	err := pool.QueryRow(ctx, sql, name).Scan(&tag.ID, &tag.Name, &tag.Description)
	if err != nil {
		return nil, fmt.Errorf("query tag failed: %w", err)
	}
	return tag, nil
}

// IsFileExists 检查文件是否已存在
func (r *repo) IsFileExists(filePath string) (bool, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return isFileExists(ctx, r.pool, filePath)
}

func isFileExists(ctx context.Context, pool *pgxpool.Pool, filePath string) (bool, error) {
	var exists bool
	sql := `SELECT EXISTS(SELECT 1 FROM tuntun.media_files WHERE file_path = $1)`
	err := pool.QueryRow(ctx, sql, filePath).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check file exists failed: %w", err)
	}
	return exists, nil
}
