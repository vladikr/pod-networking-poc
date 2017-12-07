# POD Networking POC

A few POCs of how to allow inbound traffic to VMs, with different degrees
of portability.

Prerequisites:

# On minikube:

1. Setup minikube
2. Setup weave netowkring plugin
   `kubectl apply -f https://github.com/weaveworks/weave/releases/download/v1.9.4/weave-daemonset-k8s-1.6.yaml`
3. Start the POD:
   `kubectl  create -f libvirt-macvtap.d`


