# 安装 K8S
写在最前：请先完整阅读此文档再进行 K8S 安装操作

## 使用方法
git clone 项目后，修改 conf 目录下面的配置文件，然后进入 script 目录执行 all_in_one.sh 脚本
如：
```
cd script
/bin/bash -x all_in_one.sh | tee ../logs/all_in_one.log
```

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

### backup 目录
备份文件存放目录

### conf 目录
配置文件存放目录
- k8s_deploy_list
K8S 部署结构文件

- kubeadm_init
K8S 初始化命令

- variable
变量文件

###  script 目录
脚本文件存放目录
- all_in_one.sh
K8S 一键安装脚本

- function.sh
K8S 函数脚本

- k8s_deploy.sh
K8S 部署脚本

- k8s_install.sh
K8S 环境检查及资源下载脚本

### logs 目录
日志文件存放目录

### tmp 目录
临时文件存放目录
