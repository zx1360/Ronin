package mdns

import (
	"fmt"
	"log"
	"net"
	"os"
	"strings"

	"github.com/hashicorp/mdns"
)

const serviceTag = "_monarch._tcp"

// ServiceInfo 包含 mDNS 注册所需的信息
type ServiceInfo struct {
	Instance string // 服务实例名 (e.g. "Monarch on DESKTOP-XXX")
	Port     int    // 服务端口
	IsHTTPS  bool   // 是否 HTTPS 模式
	HasAuth  bool   // 是否需要 API Key 鉴权
}

// getHostname 获取本机主机名
func getHostname() string {
	name, err := os.Hostname()
	if err != nil {
		return "Unknown"
	}
	return name
}

// buildTxtRecords 构建 TXT 记录，携带服务元信息
func buildTxtRecords(info ServiceInfo) []string {
	hostIP, err := getLocalIP()
	ipStr := ""
	if err == nil && hostIP != nil {
		ipStr = hostIP.String()
	}

	records := []string{
		fmt.Sprintf("ip=%s", ipStr),
		fmt.Sprintf("port=%d", info.Port),
	}

	if info.IsHTTPS {
		records = append(records, "scheme=https")
	} else {
		records = append(records, "scheme=http")
	}

	if info.HasAuth {
		records = append(records, "auth=yes")
	} else {
		records = append(records, "auth=no")
	}

	return records
}

// Register 注册 mDNS 服务，阻塞直到注册成功或失败
// 返回一个 channel，发送 nil 时停止服务广播
func Register(info ServiceInfo) (*mdns.Server, error) {
	// 获取本机 IP
	hostIP, err := getLocalIP()
	if err != nil {
		return nil, fmt.Errorf("获取本机IP失败: %w", err)
	}

	service, err := mdns.NewMDNSService(
		info.Instance,
		serviceTag,
		"",
		"",
		info.Port,
		[]net.IP{hostIP},
		buildTxtRecords(info),
	)
	if err != nil {
		return nil, fmt.Errorf("创建mDNS服务失败: %w", err)
	}

	server, err := mdns.NewServer(&mdns.Config{Zone: service})
	if err != nil {
		return nil, fmt.Errorf("启动mDNS服务失败: %w", err)
	}

	log.Printf("[mDNS] 服务已注册: %s (%s:%d) [%s]",
		info.Instance, hostIP, info.Port,
		strings.Join(buildTxtRecords(info), ", "))
	return server, nil
}

// getLocalIP 获取首选的本机 IPv4 地址
func getLocalIP() (net.IP, error) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return nil, err
	}

	for _, addr := range addrs {
		ipNet, ok := addr.(*net.IPNet)
		if !ok {
			continue
		}
		ip4 := ipNet.IP.To4()
		if ip4 == nil || ip4.IsLoopback() || ip4.IsLinkLocalUnicast() {
			continue
		}
		// 优先选择私有地址 (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
		if ip4.IsPrivate() {
			return ip4, nil
		}
	}

	// 回退: 取第一个非环回的 IPv4
	for _, addr := range addrs {
		ipNet, ok := addr.(*net.IPNet)
		if !ok {
			continue
		}
		ip4 := ipNet.IP.To4()
		if ip4 != nil && !ip4.IsLoopback() {
			return ip4, nil
		}
	}

	return nil, fmt.Errorf("未找到有效的本机IPv4地址")
}
