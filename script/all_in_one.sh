#!/bin/bash
# 脚本功能:
#     K8S 一键安装脚本
# 更新历史:
#     xxxx/xx/xx xxx 创建脚本
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export PATH

##### 变量区 #####

##### 函数区 #####
function echolog() {
    echo -e "$(date +%Y%m%d%H%M%S): $@ " 2>&1 | tee -a ../logs/all_in_one.log
}

function all_in_one() {
    avoid_mistouch
    copy_project
    remote_install
    /bin/bash k8s_deploy.sh
    sleep 10
    kubectl get nodes -o wide
    kubectl get pods --all-namespaces
}

##### 动作区 #####
if [[ -f function.sh ]] && [[ -f k8s_install.sh ]] && [[ -f k8s_deploy.sh ]] && [[ -f ../conf/k8s_deploy_list ]] && [[ -f ../conf/variable ]] ; then
    source ./function.sh
    source ../conf/variable
else
    echolog "运行脚本的依赖文件不存在"
    exit 1
fi

if cd ${project_path}/script ; then
    all_in_one
fi
