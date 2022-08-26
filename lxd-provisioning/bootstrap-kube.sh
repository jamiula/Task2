#!/bin/bash

# This script has been tested on Ubuntu 20.04
# For other versions of Ubuntu, you might need some tweaking
#Install docker from Docker-ce repository
echo "[TASK 1] Install docker container engine"
yum check-update >/dev/null 2>&1
curl -fsSL https://get.docker.com/ | sh >/dev/null 2>&1
#Enable docker service
echo "[TASK 2] Enable and start docker service"
systemctl start docker >/dev/null 2>&1
systemctl enable docker >/dev/null 2>&1

#Add yum repo file for kubernets
echo "[TASK 3] Add yum repo file for kubernetes"
cat >>/etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enable=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

#Install Kubernetes
echo "[TASK 4] Install kibernetes (kubeadm, kubelete and kubectl)"
yum install -y -q kubeadm kubelet kubectl >/dev/null 2>&1

#Start and Enable kubelet service 
echo "[TASK 5] Enable and start kubelet service"
systemctl enable kubelet >/dev/null 2>&1
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on==fail"' > /etc/sysconfig/kubelet
systemctl start kubelet >/dev/null 2>&1

#Install Openssh server
echo "[TASK 6] Install and configure ssh"
yum install -y -q openssh-server >/dev/null 2>&1
systemctl enable sshd >/dev/null 2>&1
systemctl start sshd >/dev/null 2>&1

echo "[TASK 7] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 8] Install additional packages"
apt install -qq -y net-tools >/dev/null 2>&1

#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ .*master.* ]]
then

  echo "[TASK 9] Pull required containers"
  kubeadm config images pull >/dev/null 2>&1

  echo "[TASK 10 Initialize Kubernetes Cluster"
  kubeadm init --pod-network-cidr=10.241.45.156/24 --ignore-preflight-errors=all >> /root/kubeinit.log 2>&1

  echo "[TASK 11] Copy kube admin config to root user .kube directory"
  mkdir /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config  

  echo "[TASK 12] Deploy Flannel network"
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml > /dev/null 2>&1

  echo "[TASK 13] Generate and save cluster join command to /joincluster.sh"
  joinCommand=$(kubeadm token create --print-join-command 2>/dev/null) 
  echo "$joinCommand --ignore-preflight-errors=all" > /joincluster.sh

fi

#######################################
# To be executed only on worker nodes #
#######################################

if [[ $(hostname) =~ .*worker.* ]]
then
  echo "[TASK 14] Join node to Kubernetes Cluster"
  apt install -qq -y sshpass >/dev/null 2>&1
  sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kmaster.lxd:/joincluster.sh /joincluster.sh 2>/tmp/joincluster.log
  bash /joincluster.sh >> /tmp/joincluster.log 2>&1
fi
