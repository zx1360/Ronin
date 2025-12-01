package tuntun

import (
	"database/sql"
	"fmt"

	"github.com/google/uuid"
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
	db *sql.DB
}

// NewRepo 创建Repo实例
func NewRepo(db *sql.DB) Repo {
	return &repo{db: db}
}

// InitSchema 初始化表结构（创建tuntun模式和4个表）
func (r *repo) InitSchema() error {
	// 1. 创建tuntun模式（如果不存在）
	createSchemaSQL := `CREATE SCHEMA IF NOT EXISTS tuntun;`
	if _, err := r.db.Exec(createSchemaSQL); err != nil {
		return fmt.Errorf("failed to create schema: %w", err)
	}

	// 2. 创建media_groups表
	createMediaGroupsSQL := `
	CREATE TABLE IF NOT EXISTS tuntun.media_groups (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		remark TEXT
	);`
	if _, err := r.db.Exec(createMediaGroupsSQL); err != nil {
		return fmt.Errorf("failed to create media_groups: %w", err)
	}

	// 3. 创建tags表
	createTagsSQL := `
	CREATE TABLE IF NOT EXISTS tuntun.tags (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		name VARCHAR(50) NOT NULL UNIQUE,
		description TEXT
	);`
	if _, err := r.db.Exec(createTagsSQL); err != nil {
		return fmt.Errorf("failed to create tags: %w", err)
	}

	// 4. 创建group_tags表（联合主键+外键约束）
	createGroupTagsSQL := `
	CREATE TABLE IF NOT EXISTS tuntun.group_tags (
		group_id UUID NOT NULL,
		tag_id UUID NOT NULL,
		PRIMARY KEY (group_id, tag_id),
		CONSTRAINT fk_group_tags_group FOREIGN KEY (group_id) REFERENCES tuntun.media_groups(id) ON DELETE CASCADE,
		CONSTRAINT fk_group_tags_tag FOREIGN KEY (tag_id) REFERENCES tuntun.tags(id) ON DELETE CASCADE
	);`
	if _, err := r.db.Exec(createGroupTagsSQL); err != nil {
		return fmt.Errorf("failed to create group_tags: %w", err)
	}

	// 5. 创建media_files表（外键约束）
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
	if _, err := r.db.Exec(createMediaFilesSQL); err != nil {
		return fmt.Errorf("failed to create media_files: %w", err)
	}

	return nil
}

// CreateMediaGroup 创建媒体组
func (r *repo) CreateMediaGroup(group *MediaGroup) error {
	if group.ID == uuid.Nil {
		group.ID = uuid.New()
	}

	sql := `INSERT INTO tuntun.media_groups (id, remark) VALUES ($1, $2)`
	_, err := r.db.Exec(sql, group.ID, group.Remark)
	if err != nil {
		return fmt.Errorf("insert media group failed: %w", err)
	}
	return nil
}

// CreateTag 创建标签（已存在则忽略）
func (r *repo) CreateTag(tag *Tag) error {
	if tag.ID == uuid.Nil {
		tag.ID = uuid.New()
	}

	// 使用ON CONFLICT避免重复创建
	sql := `INSERT INTO tuntun.tags (id, name, description) VALUES ($1, $2, $3) ON CONFLICT (name) DO NOTHING`
	_, err := r.db.Exec(sql, tag.ID, tag.Name, tag.Description)
	if err != nil {
		return fmt.Errorf("insert tag failed: %w", err)
	}
	return nil
}

// CreateGroupTag 创建组-标签关联（已存在则忽略）
func (r *repo) CreateGroupTag(gt *GroupTag) error {
	sql := `INSERT INTO tuntun.group_tags (group_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`
	_, err := r.db.Exec(sql, gt.GroupID, gt.TagID)
	if err != nil {
		return fmt.Errorf("insert group tag failed: %w", err)
	}
	return nil
}

// CreateMediaFile 创建媒体文件记录
func (r *repo) CreateMediaFile(file *MediaFile) error {
	if file.ID == uuid.Nil {
		file.ID = uuid.New()
	}

	sql := `INSERT INTO tuntun.media_files 
	(file_path, ext, file_size, create_time, date_range, mime_type, group_id, id)
	VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`

	_, err := r.db.Exec(
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
	group := &MediaGroup{}
	sql := `SELECT id, remark FROM tuntun.media_groups WHERE id = $1`
	err := r.db.QueryRow(sql, groupID).Scan(&group.ID, &group.Remark)
	if err == nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("query media group failed: %w", err)
	}
	return group, nil
}

// GetTagByName 按名称查询标签
func (r *repo) GetTagByName(name string) (*Tag, error) {
	tag := &Tag{}
	sql := `SELECT id, name, description FROM tuntun.tags WHERE name = $1`
	err := r.db.QueryRow(sql, name).Scan(&tag.ID, &tag.Name, &tag.Description)
	if err == nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("query tag failed: %w", err)
	}
	return tag, nil
}

// IsFileExists 检查文件是否已存在（通过file_path判断）
func (r *repo) IsFileExists(filePath string) (bool, error) {
	var exists bool
	sql := `SELECT EXISTS(SELECT 1 FROM tuntun.media_files WHERE file_path = $1)`
	err := r.db.QueryRow(sql, filePath).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check file exists failed: %w", err)
	}
	return exists, nil
}
