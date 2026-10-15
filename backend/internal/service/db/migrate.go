package db

import (
	"context"
	"fmt"
	"log"
	"strings"
)

// 旧表按需补列；新增列时同时更新 sqlite.sql，供全新库建表。

// addedColumn 一列的定义。
type addedColumn struct {
	table string
	name  string
	ddl   string
}

// addedColumns 为既有库补齐的列，顺序无关。
var addedColumns = []addedColumn{
	{table: "essay_articles", name: "title", ddl: "title TEXT NOT NULL DEFAULT ''"},
	{table: "essay_labels", name: "parent_id", ddl: "parent_id TEXT"},
	// 任务与产物的输入档位、执行者指纹。
	{table: "jobs", name: "input_sig", ddl: "input_sig TEXT"},
	{table: "media_ai", name: "phash_input_sig", ddl: "phash_input_sig TEXT"},
	{table: "media_ai", name: "ocr_input_sig", ddl: "ocr_input_sig TEXT"},
	{table: "media_ai", name: "caption_input_sig", ddl: "caption_input_sig TEXT"},
	{table: "embeddings", name: "input_sig", ddl: "input_sig TEXT"},
	{table: "faces", name: "input_sig", ddl: "input_sig TEXT"},
}

// ensureColumns 补齐缺失的列；表不存在时跳过（该模块未启用）。
func ensureColumns(ctx context.Context) error {
	existing, err := tableColumns(ctx)
	if err != nil {
		return err
	}
	for _, column := range addedColumns {
		columns, ok := existing[column.table]
		if !ok || columns[column.name] {
			continue
		}
		stmt := fmt.Sprintf("ALTER TABLE %s ADD COLUMN %s", column.table, column.ddl)
		if _, err := writePool.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("补充列 %s.%s 失败: %w", column.table, column.name, err)
		}
		log.Printf("数据库迁移：%s 增加列 %s", column.table, column.name)
	}
	return nil
}

// tableColumns 返回各表已有列名集合（只关心 addedColumns 涉及的列）。
func tableColumns(ctx context.Context) (map[string]map[string]bool, error) {
	tables := map[string]map[string]bool{}
	for _, column := range addedColumns {
		if _, ok := tables[column.table]; ok {
			continue
		}
		columns, err := columnsOf(ctx, column.table)
		if err != nil {
			return nil, err
		}
		tables[column.table] = columns
	}
	return tables, nil
}

// columnsOf 查询单表列名；表不存在时返回 nil（调用方据 nil 跳过）。
func columnsOf(ctx context.Context, table string) (map[string]bool, error) {
	rows, err := writePool.QueryContext(ctx, "SELECT name FROM pragma_table_info(?)", table)
	if err != nil {
		if strings.Contains(err.Error(), "no such table") {
			return nil, nil
		}
		return nil, fmt.Errorf("读取表结构失败 (%s): %w", table, err)
	}
	defer rows.Close()

	columns := map[string]bool{}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, fmt.Errorf("扫描表结构失败 (%s): %w", table, err)
		}
		columns[name] = true
	}
	return columns, rows.Err()
}
