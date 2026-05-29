package util_handler

import (
	"fmt"
	"log"
	"os"
	"sync"
	"time"
)

const (
	// 频控参数
	maxFailures = 10                 // 时间窗口内最大失败次数
	failWindow  = 10 * time.Minute   // 失败计数时间窗口
	banDuration = 3 * 24 * time.Hour // 封禁时长

	// 持久化日志路径
	banLogPath = "./static/logs.txt"
)

// IPRateLimiter IP 级别的鉴权失败频控器
type IPRateLimiter struct {
	mu             sync.RWMutex
	failedAttempts map[string][]time.Time // IP → 失败时间戳列表
	bannedIPs      map[string]time.Time   // IP → 封禁到期时间
}

var limiter *IPRateLimiter

func init() {
	limiter = &IPRateLimiter{
		failedAttempts: make(map[string][]time.Time),
		bannedIPs:      make(map[string]time.Time),
	}
	limiter.loadBannedIPs()
	go limiter.periodicCleanup()
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

// RecordFailure 记录一次鉴权失败；若达到阈值则封禁 IP 并写入日志
func (l *IPRateLimiter) RecordFailure(ip string) {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()

	// 追加失败记录
	l.failedAttempts[ip] = append(l.failedAttempts[ip], now)

	// 清理窗口外的旧记录
	cutoff := now.Add(-failWindow)
	valid := l.failedAttempts[ip][:0]
	for _, t := range l.failedAttempts[ip] {
		if t.After(cutoff) {
			valid = append(valid, t)
		}
	}
	l.failedAttempts[ip] = valid

	// 判断是否达到阈值
	if len(valid) >= maxFailures {
		l.banIPLocked(ip, now)
	}
}

// banIPLocked 封禁 IP（调用方需持有写锁）
func (l *IPRateLimiter) banIPLocked(ip string, now time.Time) {
	expiry := now.Add(banDuration)
	l.bannedIPs[ip] = expiry
	delete(l.failedAttempts, ip)

	// 持久化写入日志
	l.writeBanLog(ip, now, expiry)
}

// writeBanLog 将封禁记录追加写入日志文件
func (l *IPRateLimiter) writeBanLog(ip string, bannedAt, expiry time.Time) {
	line := fmt.Sprintf("[%s] IP %s 因频繁鉴权失败被封禁，解封时间: %s\n",
		bannedAt.Format("2006-01-02 15:04:05"),
		ip,
		expiry.Format("2006-01-02 15:04:05"),
	)

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

// loadBannedIPs 启动时从日志文件恢复仍在有效期内的封禁记录
func (l *IPRateLimiter) loadBannedIPs() {
	data, err := os.ReadFile(banLogPath)
	if err != nil {
		return // 文件不存在或无法读取，跳过
	}

	lines := splitLines(string(data))
	now := time.Now()
	loaded := 0

	for _, line := range lines {
		ip, expiry, ok := parseBanLogLine(line)
		if !ok {
			continue
		}
		if now.Before(expiry) {
			l.mu.Lock()
			l.bannedIPs[ip] = expiry
			l.mu.Unlock()
			loaded++
		}
	}

	if loaded > 0 {
		log.Printf("从日志恢复了 %d 条有效封禁记录", loaded)
	}
}

// parseBanLogLine 解析封禁日志行，提取 IP 和解封时间
//
//	格式: [2006-01-02 15:04:05] IP x.x.x.x 因频繁鉴权失败被封禁，解封时间: 2006-01-02 15:04:05
func parseBanLogLine(line string) (ip string, expiry time.Time, ok bool) {
	// 日志行固定头部 21 字符: "[2006-01-02 15:04:05]"
	if len(line) < 21 {
		return "", time.Time{}, false
	}
	// 固定标记 " IP " 位于 21~24
	if len(line) < 25 || line[21:25] != " IP " {
		return "", time.Time{}, false
	}

	// 提取 IP（在 " IP " 之后，下一个空格之前）
	ipStart := 25
	ipEnd := ipStart
	for ipEnd < len(line) && line[ipEnd] != ' ' {
		ipEnd++
	}
	ip = line[ipStart:ipEnd]

	// 提取解封时间（行末 19 字符: "2006-01-02 15:04:05"）
	if len(line) < 19 {
		return "", time.Time{}, false
	}
	expiryStr := line[len(line)-19:]
	var err error
	expiry, err = time.Parse("2006-01-02 15:04:05", expiryStr)
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

func (l *IPRateLimiter) cleanup() {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-failWindow)

	// 清理过期失败记录
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

	// 清理过期封禁
	for ip, expiry := range l.bannedIPs {
		if now.After(expiry) {
			delete(l.bannedIPs, ip)
		}
	}
}

// splitLines 简单的按行分割（避免引入 strings 包依赖）
func splitLines(s string) []string {
	var lines []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines
}
