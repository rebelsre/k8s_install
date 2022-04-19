#!/bin/bash
# 脚本功能:
#     K8S 安装脚本（环境检查 + 资源下载） 
# 更新历史:
#     xxxx/xx/xx xxx 创建脚本
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export PATH

##### 变量区 #####

##### 函数区 #####
function echolog() {
    echo -e "$(date +%Y%m%d%H%M%S): $@ " 2>&1 | tee -a ../logs/k8s_install.log
}

function ready_to_start() {
    get_system_version
    check_mem
    check_cpu
    check_network
    check_port
    check_swap
    check_selinux
    check_iptables
}

function download_resource() {
    set_iptables
    install_docker
    install_k8s
    pull_image
}

##### 动作区 #####
if [[ -f function.sh ]] && [[ -f ../conf/variable ]] ; then
    source ./function.sh
    source ../conf/variable
else
    echolog "function.sh 脚本不存在"
    exit 1
fi

ready_to_start
download_resource
