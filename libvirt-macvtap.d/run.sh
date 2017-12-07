#!/bin/sh

set -x

nic_field() { ip address show eth0 | awk "{ for(i=0;i<NF;i++) { if (\$i == \"$1\") { print \$(i+1); next; } } }" ; }
IP=$(nic_field inet | egrep -o "^[0-9.]+")
IPNET=$(nic_field inet)
MAC=$(nic_field link/ether)

ip a > /tmp/ipa
ip route list > /tmp/route

echo $IP
echo $MAC

ping google.com -c 4
ping 172.217.7.174 -c 4
ping download.fedoraproject.org -c 4


curl -L http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img -o fedora.raw

ip link set dev eth0 down
macchanger -r eth0
ip link set eth0 up

sed -i "s/MYMAC/${MAC}/g" testvm.xml

#Dummy device
#ip link add dummy0 type dummy
##ip link set dev dummy0 02:00:00:00:00:00
#ip address add 10.32.0.3 dev dummy0
#ip link set up dev dummy0

GATEWAY="${IP%.*}.1/12"
ip link add link eth0 macvlan0 type macvlan mode bridge
ip link set macvlan0 up
ip address add $GATEWAY dev macvlan0


#curl -L  https://download.fedoraproject.org/pub/fedora/linux/releases/27/CloudImages/x86_64/images/Fedora-Cloud-Base-27-1.6.x86_64.raw.xz -o fedora.raw.xz
#xz -d fedora.raw.xz


# HACK
# Use hosts's /dev to see new devices and allow macvtap
mkdir /dev.container && {
  mount --rbind /dev /dev.container
  mount --rbind /host-dev /dev

  # Keep some devices from the containerinal /dev
  keep() { mount --rbind /dev.container/$1 /dev/$1 ; }
  keep shm

  keep mqueue

  # Keep ptmx/pts for pty creation

  keep pts

  mount --rbind /dev/pts/ptmx /dev/ptmx

  # Use the container /dev/kvm if available

  [[ -e /dev.container/kvm ]] && keep kvm
}

mkdir /sys.net.container && {
  mount --rbind /sys/class/net /sys.net.container
  mount --rbind /host-sys/class/net /sys/class/net
}

mkdir /sys.devices.container && {
  mount --rbind /sys/devices /sys.devices.container
  mount --rbind /host-sys/devices /sys/devices
}

# If no cpuacct,cpu is present, symlink it to cpu,cpuacct
# Otherwise libvirt and our emulator get confused
if [ ! -d "/host-sys/fs/cgroup/cpuacct,cpu" ]; then
  echo "Creating cpuacct,cpu cgroup symlink"
  mount -o remount,rw /host-sys/fs/cgroup
  cd /host-sys/fs/cgroup
  ln -s cpu,cpuacct cpuacct,cpu
  mount -o remount,ro /host-sys/fs/cgroup
fi

mount --rbind /host-sys/fs/cgroup /sys/fs/cgroup

/usr/sbin/virtlogd -f /etc/libvirt/virtlogd.conf &
sleep 5

libvirtd &

sleep 5

ip addr del $IPNET dev eth0

virsh define testvm.xml
virsh start testvm

sleep 5

dnsmasq -q --no-hosts --no-resolv --strict-order --dhcp-authoritative --bind-dynamic --interface=macvlan0 --dhcp-range=$IP,static --dhcp-host=$MAC,$IP --user=root --log-dhcp --log-facility=/tmp/dm.log

ping $IP
while true; do sleep 5; done
