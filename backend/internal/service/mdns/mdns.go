package mdns

import (
	"errors"
	"fmt"
	"log"
	"net"
	"net/netip"

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

func buildTxtRecords(info ServiceInfo, ip netip.Addr) []string {
	records := []string{
		"ip=" + ip.String(),
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

// Register 在启动时选定局域网网卡，返回的服务由调用方关闭。
func Register(info ServiceInfo) (*mdns.Server, error) {
	iface, ip, err := localLAN()
	if err != nil {
		return nil, err
	}

	service, err := mdns.NewMDNSService(
		info.Instance,
		serviceTag,
		"",
		"",
		info.Port,
		[]net.IP{net.IP(ip.AsSlice())},
		buildTxtRecords(info, ip),
	)
	if err != nil {
		return nil, fmt.Errorf("创建mDNS服务失败: %w", err)
	}

	server, err := mdns.NewServer(&mdns.Config{Zone: service, Iface: &iface})
	if err != nil {
		return nil, fmt.Errorf("启动mDNS服务失败: %w", err)
	}

	log.Printf("[mDNS] 已在 %s 注册 %s (%s:%d)", iface.Name, info.Instance, ip, info.Port)
	return server, nil
}

func localLAN() (net.Interface, netip.Addr, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return net.Interface{}, netip.Addr{}, err
	}

	const required = net.FlagUp | net.FlagBroadcast | net.FlagMulticast
	for _, iface := range ifaces {
		if iface.Flags&required != required || !isLANAdapter(iface) {
			continue
		}
		addrs, _ := iface.Addrs()
		for _, addr := range addrs {
			ipNet, ok := addr.(*net.IPNet)
			if !ok {
				continue
			}
			if ip, ok := netip.AddrFromSlice(ipNet.IP.To4()); ok && ip.IsGlobalUnicast() {
				return iface, ip, nil
			}
		}
	}

	return net.Interface{}, netip.Addr{}, errors.New("没有可用于 mDNS 的局域网 IPv4 地址")
}
