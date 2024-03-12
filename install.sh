#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

install_x-panel() {
    systemctl stop x-panel
    cd /usr/local/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/XVGuardian/x-panel/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 x-panel 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 x-panel 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 x-panel 最新版本：${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/x-panel-linux-${arch}.tar.gz https://github.com/XVGuardian/x-panel/releases/download/${last_version}/x-panel-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-panel 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/XVGuardian/x-panel/releases/download/${last_version}/x-panel-linux-${arch}.tar.gz"
        echo -e "开始安装 x-panel v$1"
        wget -N --no-check-certificate -O /usr/local/x-panel-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-panel v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-panel/ ]]; then
        rm /usr/local/x-panel/ -rf
    fi

    tar zxvf x-panel-linux-${arch}.tar.gz
    rm x-panel-linux-${arch}.tar.gz -f
    cd x-panel
    chmod +x x-panel bin/xray-linux-${arch} x-panel.sh
    cp -f x-panel.service /etc/systemd/system/
    cp -f x-panel.sh /usr/bin/x-panel
    systemctl daemon-reload
    systemctl enable x-panel
    systemctl start x-panel
    echo -e "${green}x-panel v${last_version}${plain} 安装完成，面板已启动，"
    echo -e ""
    echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
#    echo -e "若想将 54321 修改为其它端口，输入 x-panel 命令进行修改，同样也要确保你修改的端口也是放行的"
    echo -e ""
    echo -e "如果是更新面板，则按你之前的方式访问面板"
    echo -e ""
    echo -e "x-panel 管理脚本使用方法: "
    echo -e "----------------------------------------------"
    echo -e "x-panel              - 显示管理菜单 (功能更多)"
    echo -e "x-panel start        - 启动 x-panel 面板"
    echo -e "x-panel stop         - 停止 x-panel 面板"
    echo -e "x-panel restart      - 重启 x-panel 面板"
    echo -e "x-panel status       - 查看 x-panel 状态"
    echo -e "x-panel enable       - 设置 x-panel 开机自启"
    echo -e "x-panel disable      - 取消 x-panel 开机自启"
    echo -e "x-panel log          - 查看 x-panel 日志"
    echo -e "x-panel v2-ui        - 迁移本机器的 v2-ui 账号数据至 x-panel"
    echo -e "x-panel update       - 更新 x-panel 面板"
    echo -e "x-panel install      - 安装 x-panel 面板"
    echo -e "x-panel uninstall    - 卸载 x-panel 面板"
    echo -e "----------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_x-panel $1
