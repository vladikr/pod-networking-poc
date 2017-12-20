FROM kubevirt/libvirt-kubevirt:v0.0.2

RUN dnf install -y libvirt-daemon-kvm qemu-kvm xz wget tcpdump net-tools macchanger golang git && sudo usermod -a -G libvirt $(whoami) && newgrp libvirt && dnf clean all

RUN go get github.com/krolaw/dhcp4
ADD scdhcpd.go /
RUN go build scdhcpd.go

ADD run.sh /
ADD testvm.xml /

CMD /run.sh
