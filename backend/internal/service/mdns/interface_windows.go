package mdns

import (
	"net"

	"golang.org/x/sys/windows"
)

func isLANAdapter(iface net.Interface) bool {
	const hardwareInterface = 1 << 0 // MIB_IF_ROW2.HardwareInterface
	row := windows.MibIfRow2{InterfaceIndex: uint32(iface.Index)}
	if err := windows.GetIfEntry2Ex(windows.MibIfEntryNormalWithoutStatistics, &row); err != nil {
		return false
	}
	return row.InterfaceAndOperStatusFlags&hardwareInterface != 0 &&
		(row.Type == windows.IF_TYPE_IEEE80211 || row.Type == windows.IF_TYPE_ETHERNET_CSMACD)
}
