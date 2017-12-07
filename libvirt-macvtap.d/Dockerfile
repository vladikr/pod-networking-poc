FROM kubevirt/libvirt-kubevirt:v0.0.2

RUN dnf install -y libvirt-daemon-kvm qemu-kvm xz wget tcpdump net-tools macchanger && sudo usermod -a -G libvirt $(whoami) && newgrp libvirt && dnf clean all

ADD run.sh /
ADD testvm.xml /

CMD /run.sh
