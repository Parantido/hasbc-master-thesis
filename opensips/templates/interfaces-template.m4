# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

iface wlan0 inet manual
        down ip link set wlan0 down
auto EXTERNAL_IFACE
iface EXTERNAL_IFACE inet static
	address EXTERNAL_IP
	netmask NETMASK_ADDR
	gateway GATEWAY
	post-up ip rule add from VRRP_INTERNAL_IP lookup fromInternal
	post-up ip rule add from VRRP_EXTERNAL_IP lookup fromExternal
	post-up ip route add default via GATEWAY dev EXTERNAL_IFACE table fromExternal
	post-up ip route add NETWORK/NETMASK dev EXTERNAL_IFACE table fromExternal
	post-up ip route add default via GATEWAY dev INTERNAL_IFACE table fromInternal
	post-up ip route add NETWORK/NETMASK dev INTERNAL_IFACE table fromInternal
auto INTERNAL_IFACE
iface INTERNAL_IFACE inet static
	address INTERNAL_IP
	netmask NETMASK_ADDR
	gateway GATEWAY


