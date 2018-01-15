#!/bin/sh

set -x

nic_field() { ip address show eth0 | awk "{ for(i=0;i<NF;i++) { if (\$i == \"$1\") { print \$(i+1); next; } } }" ; }
IP=$(nic_field inet | egrep -o "^[0-9.]+")
IP_CIDR=$(nic_field inet | egrep -o "^[0-9.]+/[0-9]{1,2}")
IPNET=$(nic_field inet)
MAC=$(nic_field link/ether)

ip a > /tmp/ipa
ip route list > /tmp/route

echo $IP
echo $IP_CIDR
echo $MAC

ping google.com -c 4
ping 172.217.7.174 -c 4
ping download.fedoraproject.org -c 4

curl -L http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img -o fedora.raw

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

./setup &

sleep 10

virsh define /testvm.xml
virsh start testvm

sleep 5

while true; do sleep 5; done
