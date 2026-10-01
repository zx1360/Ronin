// Package util_handler 提供鉴权中间件、频控、健康检查与运维概览接口。
package util_handler

import (
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	maxFailures = 10                 // 时间窗口内最大失败次数
	failWindow  = 10 * time.Minute   // 失败计数时间窗口
	banDuration = 3 * 24 * time.Hour // 封禁时长
)

// banLogPath 封禁日志路径，由 [SetBanLogPath] 在配置加载后设置。
// 该文件同时作为封禁状态的持久化载体：进程重启时据此恢复仍在有效期内的封禁。
var (
	banLogPath = "../_static/logs.txt"
)

// IPRateLimiter IP 级别的鉴权失败频控器
type IPRateLimiter struct {
	mu             sync.RWMutex
	failedAttempts map[string][]time.Time // IP → 失败时间戳列表
	bannedIPs      map[string]time.Time   // IP → 封禁到期时间
}

var limiter = &IPRateLimiter{
	failedAttempts: make(map[string][]time.Time),
	bannedIPs:      make(map[string]time.Time),
}

func init() {
	limiter.loadBannedIPs()
	go limiter.periodicCleanup()
}

// SetBanLogPath 设置封禁日志路径（需在配置加载后调用）
func SetBanLogPath(path string) {
	if path != "" {
		banLogPath = path
	}
}

// IsBanned 检查 IP 是否处于封禁状态；若封禁已过期则自动解封
func (l *IPRateLimiter) IsBanned(ip string) bool {
	l.mu.RLock()
	expiry, banned := l.bannedIPs[ip]
	l.mu.RUnlock()
	if !banned {
		return false
	}
	if time.Now().After(expiry) {
		l.mu.Lock()
		delete(l.bannedIPs, ip)
		delete(l.failedAttempts, ip)
		l.mu.Unlock()
		return false
	}
	return true
}

// RecordFailure 记录一次鉴权失败；达到阈值则封禁该 IP 并写入日志
func (l *IPRateLimiter) RecordFailure(ip string) {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()

	attempts := append(l.failedAttempts[ip], now)
	cutoff := now.Add(-failWindow)
	valid := attempts[:0]
	for _, t := range attempts {
		if t.After(cutoff) {
			valid = append(valid, t)
		}
	}
	l.failedAttempts[ip] = valid

	if len(valid) >= maxFailures {
		l.banIPLocked(ip, now)
	}
}

// banIPLocked 封禁 IP（调用方需持有写锁）
func (l *IPRateLimiter) banIPLocked(ip string, now time.Time) {
	expiry := now.Add(banDuration)
	l.bannedIPs[ip] = expiry
	delete(l.failedAttempts, ip)
	l.writeBanLog(ip, now, expiry)
}

// writeBanLog 将封禁记录追加写入日志文件
func (l *IPRateLimiter) writeBanLog(ip string, bannedAt, expiry time.Time) {
	line := fmt.Sprintf("[%s] IP %s 因频繁鉴权失败被封禁，解封时间: %s\n",
		formatTime(bannedAt), ip, formatTime(expiry))

	f, err := os.OpenFile(banLogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("无法写入封禁日志 %s: %v", banLogPath, err)
		return
	}
	defer f.Close()

	if _, err := f.WriteString(line); err != nil {
		log.Printf("写入封禁日志失败: %v", err)
	}
}

// GetBanExpiry 获取 IP 封禁到期时间（用于返回给客户端）
func (l *IPRateLimiter) GetBanExpiry(ip string) (time.Time, bool) {
	l.mu.RLock()
	defer l.mu.RUnlock()
	expiry, ok := l.bannedIPs[ip]
	return expiry, ok
}

const timeLayout = "2006-01-02 15:04:05"

func formatTime(t time.Time) string { return t.Format(timeLayout) }

// loadBannedIPs 启动时从日志文件恢复仍在有效期内的封禁记录。
//
// 回环地址的记录一律跳过：本机永不封禁（见 [APIKeyAuth]），
// 历史遗留的本机封禁记录不应再被恢复，否则服务重启后网页端会立刻被挡在门外。
func (l *IPRateLimiter) loadBannedIPs() {
	data, err := os.ReadFile(banLogPath)
	if err != nil {
		return // 文件不存在或无法读取，跳过
	}

	now := time.Now()
	loaded := 0
	for _, line := range strings.Split(string(data), "\n") {
		ip, expiry, ok := parseBanLogLine(line)
		if !ok || !now.Before(expiry) || isLoopbackAddr(ip) {
			continue
		}
		l.bannedIPs[ip] = expiry
		loaded++
	}

	if loaded > 0 {
		log.Printf("从日志恢复了 %d 条有效封禁记录", loaded)
	}
}

// parseBanLogLine 从封禁日志行中提取 IP 与解封时间。
//
// 写入格式见 [IPRateLimiter.writeBanLog]：
//
//	[{bannedAt}] IP {ip} 因频繁鉴权失败被封禁，解封时间: {expiry}
func parseBanLogLine(line string) (ip string, expiry time.Time, ok bool) {
	_, rest, found := strings.Cut(line, "] IP ")
	if !found {
		return "", time.Time{}, false
	}
	ip, _, found = strings.Cut(rest, " ")
	if !found || ip == "" {
		return "", time.Time{}, false
	}
	_, expiryText, found := strings.Cut(rest, "解封时间: ")
	if !found {
		return "", time.Time{}, false
	}
	expiry, err := time.Parse(timeLayout, strings.TrimSpace(expiryText))
	if err != nil {
		return "", time.Time{}, false
	}
	return ip, expiry, true
}

// periodicCleanup 定期清理过期的失败记录和封禁
func (l *IPRateLimiter) periodicCleanup() {
	ticker := time.NewTicker(30 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		l.cleanup()
	}
}

// cleanup 清理窗口外的失败记录与已过期的封禁（由 periodicCleanup 调用）
func (l *IPRateLimiter) cleanup() {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-failWindow)

	for ip, attempts := range l.failedAttempts {
		valid := attempts[:0]
		for _, t := range attempts {
			if t.After(cutoff) {
				valid = append(valid, t)
			}
		}
		if len(valid) == 0 {
			delete(l.failedAttempts, ip)
		} else {
			l.failedAttempts[ip] = valid
		}
	}

	for ip, expiry := range l.bannedIPs {
		if now.After(expiry) {
			delete(l.bannedIPs, ip)
		}
	}
}
