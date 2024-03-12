#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain}This script must be run as root!\n" && exit 1

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
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
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
        echo -e "${red}Please use CentOS 7 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# -gt 1 ]]; then
        echo && read -p "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Restart the panel, which will also restart xray?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/XVGuardian/x-panel/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will forcefully reinstall the current latest version, data will not be lost, continue?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}Canceled${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/XVGuardian/x-panel/master/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}Update completed, panel has been automatically restarted${plain}"
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel, xray will also be uninstalled?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-panel
    systemctl disable x-panel
    rm /etc/systemd/system/x-panel.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-panel/ -rf
    rm /usr/local/x-panel/ -rf

    echo ""
    echo -e "Uninstalled successfully, if you want to delete this script, run ${green}rm /usr/bin/x-panel -f${plain} after exiting the script"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset the username and password to admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-panel/x-panel setting -username admin -password admin
    echo -e "Username and password have been reset to ${green}admin${plain}, now please restart the panel"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings, account data will not be lost, username and password will not change?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-panel/x-panel setting -reset
    echo -e "All panel settings have been reset to default values, now please restart the panel, and access the panel using the default ${green}54321${plain} port"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Enter the port number[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Canceled${plain}"
        before_show_menu
    else
        /usr/local/x-panel/x-panel setting -port ${port}
        echo -e "Port setting complete, now please restart the panel, and access the panel using the newly set port ${green}${port}${plain}"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Panel is already running, no need to start again, select restart if you need to restart${plain}"
    else
        systemctl start x-panel
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}x-panel started successfully${plain}"
        else
            echo -e "${red}Panel startup failed, possibly because the startup time exceeded two seconds, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}Panel is already stopped, no need to stop again${plain}"
    else
        systemctl stop x-panel
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}x-panel and xray stopped successfully${plain}"
        else
            echo -e "${red}Panel stop failed, possibly because the stop time exceeded two seconds, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-panel
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}x-panel and xray restarted successfully${plain}"
    else
        echo -e "${red}Panel restart failed, possibly because the startup time exceeded two seconds, please check the log information later${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-panel -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-panel
    if [[ $? == 0 ]]; then
        echo -e "${green}x-panel set to start on boot successfully${plain}"
    else
        echo -e "${red}x-panel failed to set to start on boot${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-panel
    if [[ $? == 0 ]]; then
        echo -e "${green}x-panel successfully disabled from starting on boot${plain}"
    else
        echo -e "${red}x-panel failed to disable from starting on boot${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-panel.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-panel/x-panel v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-panel -N --no-check-certificate https://github.com/XVGuardian/x-panel/raw/master/x-panel.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Script download failed, please check if this machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/x-panel
        echo -e "${green}Script upgrade successful, please rerun the script${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-panel.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-panel | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-panel)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Panel is already installed, please do not reinstall${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install the panel first${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Panel status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Panel status: ${yellow}Not Running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Panel status: ${red}Not Installed${plain}"
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Auto Start: ${green}Yes${plain}"
    else
        echo -e "Auto Start: ${red}No${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "Xray Status: ${green}Running${plain}"
    else
        echo -e "Xray Status: ${red}Not Running${plain}"
    fi
}

show_usage() {
    echo "x-panel management script usage: "
    echo "------------------------------------------"
    echo "x-panel              - Display management menu (more features)"
    echo "x-panel start        - Start x-panel panel"
    echo "x-panel stop         - Stop x-panel panel"
    echo "x-panel restart      - Restart x-panel panel"
    echo "x-panel status       - Check x-panel status"
    echo "x-panel enable       - Set x-panel to start on boot"
    echo "x-panel disable      - Disable x-panel from starting on boot"
    echo "x-panel log          - View x-panel logs"
    echo "x-panel v2-ui        - Migrate v2-ui account data on this machine to x-panel"
    echo "x-panel update       - Update x-panel panel"
    echo "x-panel install      - Install x-panel panel"
    echo "x-panel uninstall    - Uninstall x-panel panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}x-panel Panel Management Script${plain}
  ${green}0.${plain} Exit Script
————————————————
  ${green}1.${plain} Install x-panel
  ${green}2.${plain} Update x-panel
  ${green}3.${plain} Uninstall x-panel
————————————————
  ${green}4.${plain} Reset Username and Password
  ${green}5.${plain} Reset Panel Settings
  ${green}6.${plain} Set Panel Port
————————————————
  ${green}7.${plain} Start x-panel
  ${green}8.${plain} Stop x-panel
  ${green}9.${plain} Restart x-panel
 ${green}10.${plain} Check x-panel status
 ${green}11.${plain} View x-panel logs
————————————————
 ${green}12.${plain} Set x-panel to start on boot
 ${green}13.${plain} Disable x-panel from starting on boot
————————————————
 ${green}14.${plain} One-click install BBR (latest kernel)
 "
    show_status
    echo && read -p "Please enter your choice [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Please enter a valid number [0-14]${plain}"
        ;;
    esac
}


if [[ $# -gt 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
