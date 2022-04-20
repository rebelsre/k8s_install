# 安装 K8S
写在最前：请先完整阅读此文档和 conf 目录下的文件再进行 K8S 安装操作

## 使用方法
git clone 项目后，修改 conf 目录下面的配置文件，然后进入 script 目录执行 all_in_one.sh 脚本，如：
```
cd script
/bin/bash -x all_in_one.sh | tee ../logs/all_in_one.log
```
- 注：需要使用 root 用户，暂时不兼容 sudo 权限
- 注：建议集群内服务器先做好 ssh 互信，否则脚本执行过程需要交互式输入服务器密码
- 注：强烈不建议重复执行 all_in_one.sh 脚本，如果执行脚本过程中出现问题，建议参考 logs 目录下的日志进行 debug

## 目录文件
### 目录结构
```
.
├── conf
│   ├── k8s_deploy_list
│   ├── kubeadm_init
│   └── variable
├── logs
│   ├── all_in_one.log
│   ├── k8s_deploy.log
│   └── k8s_install.log
├── README.md
├── script
│   ├── all_in_one.sh
│   ├── function.sh
│   ├── k8s_deploy.sh
│   └── k8s_install.sh
└── tmp
    ├── image_list
    └── kubeamd_init
```

### conf 目录
配置文件存放目录

- k8s_deploy_list
  - K8S 部署结构配置文件
- kubeadm_init
  - kubeadm init 命令配置文件
- variable
  - 变量配置文件

###  script 目录
脚本文件存放目录

- all_in_one.sh
  - K8S 一键安装脚本
- function.sh
  - K8S 函数脚本
- k8s_deploy.sh
  - K8S 部署脚本
- k8s_install.sh
  - K8S 环境检查及资源下载脚本

### logs 目录
日志文件存放目录

### tmp 目录
临时文件存放目录
