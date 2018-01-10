package network

import (
	"fmt"
	"net"

	"github.com/vishvananda/netlink"
	"kubevirt.io/kubevirt/pkg/log"

	lmf "github.com/subgraph/libmacouflage"
)

const (
	podInterface     = "eth0"
	macVlanIfaceName = "macvlan0"
	macVlanFakeIP    = "10.11.12.13"
)

type VIF struct {
	Name    string
	IP      netlink.Addr
	MAC     net.HardwareAddr
	Gateway string
}

// This method will prepare the pod management network to be used by a virtual machine
// which will own the pod network IP and MAC. Pods MAC address will be changed to a
// random address and IP will be deleted. This will also create a macvlan device with a fake IP.
// DHCP server will be started and bounded to the macvlan interface to server the original pod ip
// to the guest OS
func SetupDefaultPodNetwork() error {
	// Get IP and MAC
	// Change eth0 MAC
	// Create macvlan and set fake address
	// remove eth0 IP
	// Start DHCP

	nic := &VIF{Name: podInterface}
	link, err := netlink.LinkByName(podInterface)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to get a link for interface: %s", podInterface)
		return err
	}

	// get IP address
	addrList, err := netlink.AddrList(link, netlink.FAMILY_V4)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to get an ip address for %s", podInterface)
		return err
	}
	if len(addrList) == 0 {
		return fmt.Errorf("No IP address found on %s", podInterface)
	}
	nic.IP = addrList[0]

	// Get interface gateway
	routes, err := netlink.RouteList(link, netlink.FAMILY_V4)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to get routes for %s", podInterface)
		return err
	}
	if len(routes) == 0 {
		return fmt.Errorf("No gateway address found in routes for %s", podInterface)
	}
	nic.Gateway = routes[0].Gw.String()

	// Get interface MAC address
	mac, err := GetMacDetails(podInterface)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to get MAC for %s", podInterface)
		return err
	}
	nic.MAC = mac

	// Remove IP from POD interface
	err = netlink.AddrDel(link, &nic.IP)

	if err != nil {
		log.Log.Reason(err).Errorf("failed to delete link for interface: %s", podInterface)
		return err
	}

	// Set interface link to down to change its MAC address
	err = netlink.LinkSetDown(link)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to bring link down for interface: %s", podInterface)
		return err
	}

	_, err = ChangeMacAddr(podInterface)
	if err != nil {
		return err
	}

	err = netlink.LinkSetUp(link)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to bring link up for interface: %s", podInterface)
		return err
	}

	// Create a macvlan link
	macvlan := &netlink.Macvlan{
		LinkAttrs: netlink.LinkAttrs{
			Name:        macVlanIfaceName,
			ParentIndex: link.Attrs().Index,
		},
		Mode: netlink.MACVLAN_MODE_BRIDGE,
	}

	//Create macvlan interface
	if err := netlink.LinkAdd(macvlan); err != nil {
		log.Log.Reason(err).Errorf("failed to create macvlan interface")
		return err
	}

	//get macvlan link
	macvlink, err := netlink.LinkByName(macVlanIfaceName)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to get a link for interface: %s", macVlanIfaceName)
		return err
	}
	err = netlink.LinkSetUp(macvlink)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to bring link up for interface: %s", macVlanIfaceName)
		return err
	}

	// set fake ip on macvlan interface
	fakeaddr, _ := netlink.ParseAddr(macVlanFakeIP)
	if err := netlink.AddrAdd(macvlink, fakeaddr); err != nil {
		log.Log.Reason(err).Errorf("failed to set macvlan IP")
		return err
	}

	// Start DHCP

	return nil
}

// GetMacDetails from an interface
func GetMacDetails(iface string) (net.HardwareAddr, error) {
	currentMac, err := lmf.GetCurrentMac(iface)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to get mac information for interface: %s", iface)
		return nil, err
	}
	return currentMac, nil
}

// ChangeMacAddr changes the MAC address for a agiven interface
func ChangeMacAddr(iface string) (net.HardwareAddr, error) {
	var mac net.HardwareAddr

	currentMac, err := GetMacDetails(iface)
	if err != nil {
		return nil, err
	}

	changed, err := lmf.SpoofMacRandom(iface, false)
	if err != nil {
		log.Log.Reason(err).Errorf("failed to spoof MAC for iface: %s", iface)
		return nil, err
	}

	if changed {
		mac, err = GetMacDetails(iface)
		if err != nil {
			return nil, err
		}
		log.Log.Reason(err).Errorf("Updated Mac for iface: %s - %s", iface, mac)
	}
	return currentMac, nil
}
