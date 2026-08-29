// Package comix_repo 提供 comix 爬虫管理所需的直查库访问（毫秒级）。
//
// 职责边界：Go 端负责**所有查询 + 删除**（桌面端数据直查库），
// Python 端只保留爬虫操作（search/add/add-url/download/update-check/clean/init）。
// 数据模型与 comix CLI 的 JSON 输出保持一致，客户端（桌面端）无需感知数据来源变化。
package comix_repo

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"monarch/internal/service/comix"
	"monarch/internal/service/db"
)

// Site comix 站点。
type Site struct {
	Code    string `json:"code"`
	Name    string `json:"name"`
	BaseURL string `json:"base_url"`
	Enabled bool   `json:"enabled"`
}

// Comic 已登记漫画（list 语义，含聚合统计）。
type Comic struct {
	ComicID       int    `json:"comic_id"`
	Title         string `json:"title"`
	Site          string `json:"site"`
	SiteName      string `json:"site_name"`
	DetailURL     string `json:"detail_url"`
	RelDir        string `json:"rel_dir"`
	TotalChapters int    `json:"total_chapters"`
	Downloaded    int    `json:"downloaded"`
	Failed        int    `json:"failed"`
	MaxChapterNo  int    `json:"max_chapter_no"`
}

// Chapter 章节（chapters 语义，精简列）。
type Chapter struct {
	ID        int    `json:"id"`
	ChapterNo int    `json:"chapter_no"`
	Title     string `json:"title"`
	Status    string `json:"status"`
	PageCount int    `json:"page_count"`
	RelDir    string `json:"rel_dir"`
	Error     string `json:"error"`
}

// ErrComicNotFound 漫画不存在。
var ErrComicNotFound = errors.New("漫画不存在")

// MatchSiteByURL 根据详情页 URL 的 host 匹配已注册站点（comix.site.base_url）。
// 比较时忽略协议与 "www." 前缀；匹配失败返回不支持站点的明确错误。
func MatchSiteByURL(rawURL string, sites []Site) (string, error) {
	parsed, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil || parsed.Host == "" {
		return "", fmt.Errorf("URL 无效: %s", rawURL)
	}
	host := normalizeHost(parsed.Host)
	for _, site := range sites {
		if !site.Enabled || site.BaseURL == "" {
			continue
		}
		base, parseErr := url.Parse(site.BaseURL)
		if parseErr != nil || base.Host == "" {
			continue
		}
		if normalizeHost(base.Host) == host {
			return site.Code, nil
		}
	}
	return "", fmt.Errorf("不支持的漫画站点: %s（支持: %s）", parsed.Host, supportedSiteNames(sites))
}

// normalizeHost 统一 host 比较形式（小写、去 "www." 前缀、去端口）。
func normalizeHost(host string) string {
	host = strings.ToLower(strings.TrimSpace(host))
	if h, _, err := net.SplitHostPort(host); err == nil {
		host = h
	}
	return strings.TrimPrefix(host, "www.")
}

func supportedSiteNames(sites []Site) string {
	var names []string
	for _, site := range sites {
		if site.Enabled && site.BaseURL != "" {
			names = append(names, site.Name)
		}
	}
	if len(names) == 0 {
		return "无"
	}
	return strings.Join(names, " / ")
}

// ListSites 列出全部站点。
func ListSites() ([]Site, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return listSites(ctx, db.GetPool())
}

func listSites(ctx context.Context, pool *pgxpool.Pool) ([]Site, error) {
	rows, err := pool.Query(ctx, `
		SELECT code, name, base_url, enabled
		FROM comix.site
		ORDER BY id
	`)
	if err != nil {
		return nil, fmt.Errorf("查询 comix 站点失败: %w", err)
	}
	defer rows.Close()

	var sites []Site
	for rows.Next() {
		var s Site
		if err := rows.Scan(&s.Code, &s.Name, &s.BaseURL, &s.Enabled); err != nil {
			return nil, fmt.Errorf("扫描站点数据失败: %w", err)
		}
		sites = append(sites, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("迭代站点结果集失败: %w", err)
	}
	return sites, nil
}

// ListComics 列出全部已登记漫画（单条 SQL 聚合，替代 Python 端 N+1 查询）。
func ListComics() ([]Comic, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return listComics(ctx, db.GetPool())
}

func listComics(ctx context.Context, pool *pgxpool.Pool) ([]Comic, error) {
	rows, err := pool.Query(ctx, `
		SELECT
			c.id,
			c.title,
			s.code,
			s.name,
			c.detail_url,
			c.rel_dir,
			COUNT(ch.id)                                    AS total_chapters,
			COUNT(ch.id) FILTER (WHERE ch.status = 'done')  AS downloaded,
			COUNT(ch.id) FILTER (WHERE ch.status = 'failed') AS failed,
			COALESCE(MAX(ch.chapter_no), 0)                 AS max_chapter_no
		FROM comix.comic c
		JOIN comix.site s ON s.id = c.site_id
		LEFT JOIN comix.chapter ch ON ch.comic_id = c.id
		GROUP BY c.id, c.title, s.code, s.name, c.detail_url, c.rel_dir
		ORDER BY c.id
	`)
	if err != nil {
		return nil, fmt.Errorf("查询 comix 漫画列表失败: %w", err)
	}
	defer rows.Close()

	var comics []Comic
	for rows.Next() {
		var c Comic
		if err := rows.Scan(&c.ComicID, &c.Title, &c.Site, &c.SiteName,
			&c.DetailURL, &c.RelDir, &c.TotalChapters,
			&c.Downloaded, &c.Failed, &c.MaxChapterNo); err != nil {
			return nil, fmt.Errorf("扫描漫画数据失败: %w", err)
		}
		comics = append(comics, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("迭代漫画结果集失败: %w", err)
	}
	return comics, nil
}

// ListChapters 列出指定漫画的章节（精简列，避免大 payload）。
func ListChapters(comicID int) ([]Chapter, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return listChapters(ctx, db.GetPool(), comicID)
}

func listChapters(ctx context.Context, pool *pgxpool.Pool, comicID int) ([]Chapter, error) {
	// 与 CLI 语义一致：漫画不存在时返回业务错误
	var exists bool
	if err := pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM comix.comic WHERE id = $1)`, comicID).Scan(&exists); err != nil {
		return nil, fmt.Errorf("查询漫画存在性失败: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("%w: %d", ErrComicNotFound, comicID)
	}

	rows, err := pool.Query(ctx, `
		SELECT id, chapter_no, title, status, page_count, rel_dir, error
		FROM comix.chapter
		WHERE comic_id = $1
		ORDER BY chapter_no
	`, comicID)
	if err != nil {
		return nil, fmt.Errorf("查询 comix 章节失败: %w", err)
	}
	defer rows.Close()

	var chapters []Chapter
	for rows.Next() {
		var c Chapter
		if err := rows.Scan(&c.ID, &c.ChapterNo, &c.Title, &c.Status,
			&c.PageCount, &c.RelDir, &c.Error); err != nil {
			return nil, fmt.Errorf("扫描章节数据失败: %w", err)
		}
		chapters = append(chapters, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("迭代章节结果集失败: %w", err)
	}
	return chapters, nil
}

// DeletedComic 删除结果。
type DeletedComic struct {
	ComicID      int    `json:"comic_id"`
	Title        string `json:"title"`
	FilesRemoved bool   `json:"files_removed"`
	LeftoverPath string `json:"leftover_path,omitempty"`
}

// DeleteComic 删除漫画（DB 级联 + 可选文件删除）。
//
// 安全顺序：① 解析存储路径 → ② 将目录改名（原子、可回滚）→ ③ 删除 DB 记录
// （外键级联清理章节/图片/任务/别名）→ ④ DB 失败则改名回滚并返回错误 →
// ⑤ 成功后移除改名目录（尽力而为，失败时报告残留路径）。
// keepFiles=true 时只删 DB 记录，文件原样保留（便于可回退验收）。
func DeleteComic(comicID int, keepFiles bool) (*DeletedComic, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	return deleteComic(ctx, db.GetPool(), comicID, keepFiles)
}

func deleteComic(ctx context.Context, pool *pgxpool.Pool, comicID int, keepFiles bool) (*DeletedComic, error) {
	var title, relDir string
	err := pool.QueryRow(ctx,
		`SELECT title, rel_dir FROM comix.comic WHERE id = $1`, comicID,
	).Scan(&title, &relDir)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("%w: %d", ErrComicNotFound, comicID)
		}
		return nil, fmt.Errorf("查询漫画失败: %w", err)
	}

	result := &DeletedComic{ComicID: comicID, Title: title}

	// ① 文件目录改名（先于 DB 删除，保证可回滚；keep_files 跳过）
	renamed := ""
	absDir := ""
	if !keepFiles && relDir != "" {
		absDir, err = comix.StoragePath(relDir)
		if err != nil {
			return nil, err
		}
		if fi, statErr := os.Stat(absDir); statErr == nil && fi.IsDir() {
			renamed = absDir + ".deleting_" + strconv.FormatInt(time.Now().Unix(), 10)
			if renameErr := os.Rename(absDir, renamed); renameErr != nil {
				return nil, fmt.Errorf("重命名漫画目录失败: %w", renameErr)
			}
		}
		result.FilesRemoved = true // 目录不存在时视为已清理
	}

	// ② 删除 DB 记录（外键级联）
	if _, err := pool.Exec(ctx,
		`DELETE FROM comix.comic WHERE id = $1`, comicID); err != nil {
		if renamed != "" {
			_ = os.Rename(renamed, absDir) // 回滚改名
		}
		return nil, fmt.Errorf("删除漫画记录失败(已回滚目录改名): %w", err)
	}

	// ③ 移除改名目录（尽力而为）
	if renamed != "" {
		if removeErr := comix.RemoveDirSafely(renamed); removeErr != nil {
			result.FilesRemoved = false
			result.LeftoverPath = renamed
		}
	}
	return result, nil
}

// RelDirOf 返回漫画的存储相对路径（供桌面端展示/跳转）。
func RelDirOf(comicID int) (string, error) {
	ctx, cancel := db.GetDefaultCtx()
	defer cancel()
	var relDir string
	err := db.GetPool().QueryRow(ctx,
		`SELECT rel_dir FROM comix.comic WHERE id = $1`, comicID).Scan(&relDir)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", fmt.Errorf("%w: %d", ErrComicNotFound, comicID)
		}
		return "", err
	}
	return filepath.ToSlash(relDir), nil
}
