package util_handler

import (
	"fmt"
	"log"
	"net"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	maxFailures = 10
	failWindow  = 10 * time.Minute
	banDuration = 3 * 24 * time.Hour
	timeLayout  = "2006-01-02 15:04:05"
)

type ipRateLimiter struct {
	mu          sync.RWMutex
	logPath     string
	attempts    map[string][]time.Time
	bans        map[string]time.Time
	nextCleanup time.Time
}

func newIPRateLimiter(path string) *ipRateLimiter {
	l := &ipRateLimiter{logPath: path, attempts: make(map[string][]time.Time), bans: make(map[string]time.Time)}
	data, _ := os.ReadFile(path)
	now := time.Now()
	for _, line := range strings.Split(string(data), "\n") {
		_, rest, _ := strings.Cut(line, "] IP ")
		ip, _, _ := strings.Cut(rest, " ")
		_, rawExpiry, _ := strings.Cut(rest, "解封时间: ")
		expiry, err := time.ParseInLocation(timeLayout, strings.TrimSpace(rawExpiry), time.Local)
		if err == nil && expiry.After(now) && net.ParseIP(ip) != nil && !isLoopbackAddr(ip) {
			l.bans[ip] = expiry
		}
	}
	return l
}

func (l *ipRateLimiter) banExpiry(ip string) time.Time {
	l.mu.RLock()
	defer l.mu.RUnlock()
	if expiry := l.bans[ip]; time.Now().Before(expiry) {
		return expiry
	}
	return time.Time{}
}

func (l *ipRateLimiter) recordFailure(ip string) time.Time {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	if expiry := l.bans[ip]; now.Before(expiry) {
		return expiry
	}
	cutoff := now.Add(-failWindow)
	if !now.Before(l.nextCleanup) {
		l.nextCleanup = now.Add(failWindow)
		for ip, attempts := range l.attempts {
			if !attempts[len(attempts)-1].After(cutoff) {
				delete(l.attempts, ip)
			}
		}
		for ip, expiry := range l.bans {
			if !now.Before(expiry) {
				delete(l.bans, ip)
			}
		}
	}
	attempts := l.attempts[ip]
	for len(attempts) > 0 && !attempts[0].After(cutoff) {
		attempts = attempts[1:]
	}
	if len(attempts)+1 < maxFailures {
		l.attempts[ip] = append(attempts, now)
		return time.Time{}
	}

	expiry := now.Add(banDuration)
	l.bans[ip] = expiry
	delete(l.attempts, ip)
	if err := l.appendBan(ip, now, expiry); err != nil {
		log.Printf("写入封禁日志失败: %v", err)
	}
	return expiry
}

func (l *ipRateLimiter) appendBan(ip string, now, expiry time.Time) error {
	f, err := os.OpenFile(l.logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = fmt.Fprintf(f, "[%s] IP %s 因频繁鉴权失败被封禁，解封时间: %s\n",
		now.Format(timeLayout), ip, expiry.Format(timeLayout))
	return err
}
