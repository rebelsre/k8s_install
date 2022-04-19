#!/bin/bash
# 脚本功能:
#     K8S 部署脚本
# 更新历史:
#     xxxx/xx/xx xxx 创建脚本
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export PATH

##### 变量区 #####

##### 函数区 #####
function echolog() {
    echo -e "$(date +%Y%m%d%H%M%S): $@ " 2>&1 | tee -a ../logs/k8s_deploy.log
}

function k8s_deploy() {
    set_hosts
    kubeadm_init
    node_join
    install_network_module
}

##### 动作区 #####
if [[ -f function.sh ]] && [[ -f ../conf/k8s_deploy_list ]] && [[ -f ../conf/kubeadm_init ]] && [[ -f ../conf/variable ]] ; then
    source ./function.sh
    source ../conf/variable
else
    echolog "运行脚本的依赖文件不存在"
    exit 1
fi

k8s_deploy
