#!/bin/bash
# 脚本功能:
#     函数脚本
# 更新历史:
#     xxxx/xx/xx xxx 创建脚本
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export PATH

##### 函数区 #####
function avoid_mistouch() { # 防误触
    read -t 30 -p "此脚本为 K8S 安装脚本，确认要执行？（Y|N）" avoid_mistouch
    case ${avoid_mistouch} in
        Y) echo "继续安装 K8S~" ;;
        N) echo "拜拜~" && exit 1 ;;
        *) echo "输入有误~" && exit 1 ;;
    esac
}

function ssh_key_copy() { # SSH 互信（这个模块暂未引入使用，如需使用，请先自测）
    local pub_file="~/.ssh/id_rsa.pub"
    read -p "为了方便部署，现在会先配置集群服务器免密访问，期间可能需要输入服务器密码。（确认选 Y，跳过选 N）" ssh_key_copy
    case ${ssh_key_copy} in
        Y)
            echolog "开始配置 ssh 免密登录~"
            if [[ ! -f ${pub_file} ]] ; then
                ssh-keygen -t rsa -N '' -f id_rsa -q
            fi
            for ip in $(cat ${deploy_file} | grep -v "#" | awk -F, '{print $1}')
            do
                ssh-copy-id -p ${ssh_port:-"22"} ${ip}
            done
            ;;
        N)
            echo "跳过互信环节"
            ;;
        *)
            echo "输入有误~" && exit 1
            ;;
    esac
}

function copy_project() { # 分发项目文件到集群服务器
    for ip in $(cat ${deploy_file} | grep -v "#" | grep -v "localhost" | awk -F, '{print $1}')
    do
        ssh -p ${ssh_port:-"22"} ${ip} "mkdir -p ${project_path%/*}" # ${ssh_port:-"22"} 指如果不配置 ssh_port 变量则使用 22 作为默认变量
        scp -r -P ${ssh_port:-"22"} ${project_path} ${ip}:${project_path%/*}/ # ${project_path%/*} 指裁切变量，例如：裁切前：/data/sh/k8s_install，裁切后：/data/sh
    done
}

function remote_install() { # 远程到集群服务器执行 k8s_install.sh 脚本
    for ip in $(cat ${deploy_file} | grep -v "#" | awk -F, '{print $1}')
    do
        ssh -p ${ssh_port:-"22"} ${ip} "cd ${project_path}/script && /bin/bash k8s_install.sh"
    done
}

function get_system_version() { # 获取操作系统版本
    if [[ ! -f /etc/os-release ]] ; then
        system_version=$(cat /etc/redhat-release)
    else
        system_version=$(cat /etc/os-release | grep -Po '(?<=PRETTY_NAME=")[^"]*')
    fi
}

function check_mem() { # 检查系统内存
    if [[ $(cat /proc/meminfo | grep "MemTotal" | awk '{print $2}') -lt 1992294 ]] ; then # 1992294 KB ~= 1.9 GB
        echolog "ERROR: 不满足 '每台机器 2 GB 或更多的 RAM'"
        exit 1
    fi
}

function check_cpu() { # 检查 CPU 核心数
    if [[ $(cat /proc/cpuinfo | grep "cpu cores" | uniq | awk '{print $NF}') -lt 2 ]] ; then
        echolog "ERROR: 不满足 '2 CPU 核或更多'"
        exit 1
    fi
}

function check_network() { # 检查网络（需配置好 DNS 和能连通公网，脚本涉及公网下载内容）
    if ! ping -c 1 www.baidu.com > /dev/null 2>&1 ; then
        echolog "ERROR: ping www.baidu.com 不通"
        exit 1
    fi
}

function check_port() { # 检查端口
    if [[ -e "$(ss -an | grep -w 6443)" ]] ; then
        echolog "ERROR: 6443 端口被占用"
        exit 1
    fi
}

function check_swap() { # 检查虚拟内存
    if [[ $(cat /proc/meminfo | grep SwapTotal | awk '{print $2}') != 0 ]] ; then
        echolog "WARNING: 交换分区未禁用，尝试禁用交换分区"
        swapoff -a
        sed -i.bak '/swap/s/^/#/' /etc/fstab
        if [[ $(cat /proc/meminfo | grep SwapTotal | awk '{print $2}') != 0 ]] ; then
            echolog "ERROR: 禁用交换分区失败"
            exit 1
        fi
    fi
}

function check_selinux() { # 检查 SELinux
    if [[ "$(getenforce)" == "Disabled" ]] ; then
        echolog "INFO: SELinux 已禁用，跳过"
    else
        setenforce 0
        sed -i.bak '/SELINUX=/s/[a-z]*$/disabled/' /etc/sysconfig/selinux
        if [[ "$(getenforce)" == "Disabled" ]] ; then
            echolog "INFO: SELinux 已禁用"
        fi
    fi
}

function check_iptables() { # 检查防火墙
    local control_ip=$(cat ${kubeadm_init_conf} | grep -v "#" | grep -Po "(?<=--control-plane-endpoint=)[^\s]*") # 获取 kubeadm_init 命令中 --control-plane-endpoint= 配置的 IP
    if [[ $(ps -ef | grep -v grep | grep firewalld | wc -l) -gt 0 ]] ; then
        for ip in $(cat ${deploy_file} | grep -v "#" | cut -d, -f1)
        do
            firewall-cmd --permanent --zone=trusted --add-source=${ip}
        done
        if [[ "${control_ip}" ]] ; then
            firewall-cmd --permanent --zone=trusted --add-source=${control_ip}
        fi
        echolog "firewalld 已经临时开放集群 IP"
    else
        for ip in $(cat ${deploy_file} | grep -v "#" | cut -d, -f1)
        do
            iptables -A INPUT -s ${ip}/32 -j ACCEPT
        done
        if [[ "${control_ip}" ]] ; then
            iptables -A INPUT -s ${control_ip}/32 -j ACCEPT
        fi
        echolog "iptables 已经临时开放集群 IP"
    fi
}

function set_iptables { # 允许 iptables 检查桥接流量
    if [[ -z "$(lsmod | grep br_netfilter)" ]] ; then
        modprobe br_netfilter
        cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
    fi
        cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    if sysctl --system > /dev/null 2>&1 ; then
        echolog "INFO: 允许 iptables 检查桥接流量"
    fi
}

function install_docker() { # 安装 docker
    if docker version > /dev/null 2>&1 ; then
        echolog "WARNING: docker 已安装，跳过这一步"
    else
        if
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install docker-ce${docker_version:-"-20.10.6"} docker-ce-cli${docker_version:-"-20.10.6"} containerd.io -y
            mkdir /etc/docker
            cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
            systemctl enable --now docker
        then
            echolog "INFO: docker${docker_version:-"-20.10.6"} 安装成功"
        else
            echolog "ERROR: docker${docker_version:-"-20.10.6"} 安装失败"
        fi
    fi
}

function install_k8s() { # 安装 kubeadm、kubelet 和 kubectl
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
po_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    if
        yum install -y kubelet${kubeadm_verison:-"-1.23.5"} kubeadm${kubeadm_verison:-"-1.23.5"} kubectl${kubeadm_verison:-"-1.23.5"} --disableexcludes=kubernetes --nogpgcheck
    then
        systemctl enable --now kubelet
        echolog "INFO: kubeadm、kubelet 和 kubectl 安装成功"
    else
        echolog "ERROR: kubeadm、kubelet 和 kubectl 安装失败"
        exit 1
    fi
}

function pull_image() { # 拉取镜像
    if
        kubeadm config images pull --image-repository registry.aliyuncs.com/google_containers
    then
        kubeadm config images list > ${image_file}
        local apiserver_version=$(cat ${image_file} | grep "apiserver" | awk -F ':' '{print $2}')
        local controller_version=$(cat ${image_file} | grep "controller" | awk -F ':' '{print $2}')
        local scheduler_version=$(cat ${image_file} | grep "scheduler" | awk -F ':' '{print $2}')
        local proxy_version=$(cat ${image_file} | grep "proxy" | awk -F ':' '{print $2}')
        local pause_version=$(cat ${image_file} | grep "pause" | awk -F ':' '{print $2}')
        local etcd_version=$(cat ${image_file} | grep "etcd" | awk -F ':' '{print $2}')
        local coredns_version=$(cat ${image_file} | grep "coredns" | awk -F ':' '{print $2}')
        # 修改标签
        docker tag registry.aliyuncs.com/google_containers/kube-apiserver:${apiserver_version} k8s.gcr.io/kube-apiserver:${apiserver_version}
        docker tag registry.aliyuncs.com/google_containers/kube-proxy:${proxy_version} k8s.gcr.io/kube-proxy:${proxy_version}
        docker tag registry.aliyuncs.com/google_containers/kube-controller-manager:${controller_version} k8s.gcr.io/kube-controller-manager:${controller_version}
        docker tag registry.aliyuncs.com/google_containers/kube-scheduler:${scheduler_version} k8s.gcr.io/kube-scheduler:${scheduler_version}
        docker tag registry.aliyuncs.com/google_containers/etcd:${etcd_version} k8s.gcr.io/etcd:${etcd_version}
        docker tag registry.aliyuncs.com/google_containers/coredns:${coredns_version} k8s.gcr.io/coredns/coredns:${coredns_version}
        docker tag registry.aliyuncs.com/google_containers/pause:${pause_version} k8s.gcr.io/pause:${pause_version}
        # 去掉多余标签
        docker rmi registry.aliyuncs.com/google_containers/kube-apiserver:${apiserver_version}
        docker rmi registry.aliyuncs.com/google_containers/kube-proxy:${proxy_version}
        docker rmi registry.aliyuncs.com/google_containers/kube-controller-manager:${controller_version}
        docker rmi registry.aliyuncs.com/google_containers/kube-scheduler:${scheduler_version}
        docker rmi registry.aliyuncs.com/google_containers/etcd:${etcd_version}
        docker rmi registry.aliyuncs.com/google_containers/coredns:${coredns_version}
        docker rmi registry.aliyuncs.com/google_containers/pause:${pause_version}
        echolog "INFO: K8S 镜像拉取成功"
    else
        echolog "ERROR: K8S 镜像拉取失败"
        exit 1
    fi
}

function set_hosts() { # 添加 hosts 配置
    IFS=$'\n' # 使用换行符作为分隔符
    for host in $(cat ${deploy_file} | grep -v "#" | awk -F, '{print $1,$2}')
    do
        echo ${host} >> /etc/hosts
    done
    for ip in $(cat ${deploy_file} | grep -v "#" | grep -v "localhost" | cut -d, -f1)
    do
        ssh -p ${ssh_port:-"22"} ${ip} "cp -a /etc/hosts /etc/hosts_$(date +%s).bak"
        scp -P ${ssh_port:-"22"} /etc/hosts ${ip}:/etc/
    done
    unset IFS
}

function kubeadm_init() { # kubeadm 初始化
    if $(cat ${kubeadm_init_conf} | grep -v "#") | tee ${kubeadm_init_file} ; then
        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
        chown $(id -u):$(id -g) ${HOME}/.kube/config
        echolog "INFO: K8S 初始化成功"
    else
        echolog "ERROR: K8S 初始化失败"
        exit 1
    fi
}

function node_join() { # 添加 k8s 节点
    local join_command=$(cat ${kubeadm_init_file} | grep "kubeadm join" | tail -1 | tr -d '\\')
    local cert_command=$(cat ${kubeadm_init_file} | grep "\-\-discovery-token-ca-cert-hash" | tail -1 | tr -d '\\' | tr -d '\t')
    local control_command=$(cat ${kubeadm_init_file} | grep "\-\-control-plane" | tail -1 | tr -d '\\' | tr -d '\t')
    local join_args=$(cat ${kubeadm_join_conf} | grep -v "#")
    local master_join_command="${join_command} ${cert_command} ${control_command} ${join_args}" # 拼接 master 节点 join 命令
    local worker_join_command="${join_command} ${cert_command} ${join_args}" # 拼接 worker 节点 join 命令
    for master_ip in $(cat ${deploy_file} | grep -v "#" | grep -v "localhost" | grep "master" | cut -d, -f1)
    do
        ssh -p ${ssh_port:-"22"} ${master_ip} "${master_join_command}"
        ssh -p ${ssh_port:-"22"} ${master_ip} "mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config"
    done
    for worker_ip in $(cat ${deploy_file} | grep -v "#" | grep "worker" | cut -d, -f1)
    do
        ssh -p ${ssh_port:-"22"} ${worker_ip} "${worker_join_command}"
    done
}

function install_network_module() { # Pod 网络附加组件安装（默认使用 weave）
    if kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" ; then
        echolog "INFO: Pod 网络附加组件安装成功"
    else
        echolog "ERROR: Pod 网络附加组件安装失败"
    fi
}
