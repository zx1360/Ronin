//go:build !windows

package mdns

import "net"

func isLANAdapter(iface net.Interface) bool {
	return len(iface.HardwareAddr) != 0 && iface.Flags&net.FlagPointToPoint == 0
}
