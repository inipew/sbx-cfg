#!/bin/bash

#####################################################
#This shell script is used for sing-box installation
#Usage：
#
#Author:FranzKafka
#Date:2022-09-15
#Version:0.0.1
#####################################################

#Some basic definitions
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

#os
OS_RELEASE=''

#arch
OS_ARCH=''

#sing-box version
SING_BOX_VERSION=''

#script version
SING_BOX_YES_VERSION='0.0.2'

#package download path
DOWNLAOD_PATH='/usr/local/sing-box'

#backup config path
CONFIG_BACKUP_PATH='/usr/local/etc'

#config install path
CONFIG_FILE_PATH='/usr/local/etc/sing-box/config'

#binary install path
BINARY_FILE_PATH='/usr/local/bin/sing-box'

#scritp install path
SCRIPT_FILE_PATH='/usr/local/sbin/sing-box'

#service install path
SERVICE_FILE_PATH='/etc/systemd/system/sing-box.service'

#log file save path
DEFAULT_LOG_FILE_SAVE_PATH='/usr/local/sing-box/sing-box.log'

FILE_LIST=(
    "00_log.json"
    "01_dns.json"
    "02_vless_ws.json"
    "03_vmess_ws.json"
    "04_trojan_ws.json"
    "11_ipv4_outbouds.json"
    "12_routing.json"
)
#sing-box status define
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255

#log file size which will trigger log clear
#here we set it as 25M
declare -r DEFAULT_LOG_FILE_DELETE_TRIGGER=25

#utils
function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default$2]: " temp
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

#Root check
[[ $EUID -ne 0 ]] && LOGE "Please use the root user to run the script" && exit 1

#System check
os_check() {
    LOGI "Check the current system..."
    if [[ -f /etc/redhat-release ]]; then
        OS_RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    else
        LOGE "System detection error, please contact the script author!" && exit 1
    fi
    LOGI "System detection is completed, the current system is:${OS_RELEASE}"
}

#arch check
arch_check() {
    LOGI "Detect the current system architecture..."
    OS_ARCH=$(arch)
    LOGI "The current system architecture is ${OS_ARCH}"

    if [[ ${OS_ARCH} == "x86_64" || ${OS_ARCH} == "x64" || ${OS_ARCH} == "amd64" ]]; then
        OS_ARCH="amd64"
    elif [[ ${OS_ARCH} == "aarch64" || ${OS_ARCH} == "arm64" ]]; then
        OS_ARCH="arm64"
    else
        OS_ARCH="amd64"
        LOGE "Failed to detect system architecture, use default architecture: ${OS_ARCH}"
    fi
    LOGI "System architecture detection completed,The current system architecture is:${OS_ARCH}"
}

#sing-box status check,-1 means didn't install,0 means failed,1 means running
status_check() {
    if [[ ! -f "${SERVICE_FILE_PATH}" ]]; then
        return ${SING_BOX_STATUS_NOT_INSTALL}
    fi
    temp=$(systemctl status sing-box | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return ${SING_BOX_STATUS_RUNNING}
    else
        return ${SING_BOX_STATUS_NOT_RUNNING}
    fi
}

#check config provided by sing-box core
config_check() {
    if [[ ! -f "${CONFIG_FILE_PATH}/00_log.json" ]]; then
        LOGE "${CONFIG_FILE_PATH} does not exist, configuration check failed"
        return
    else
        info=$(${BINARY_FILE_PATH} check -C ${CONFIG_FILE_PATH})
        if [[ $? -ne 0 ]]; then
            LOGE "Configuration check failed, please check the log"
        else
            LOGI "Congratulations: configuration check passed"
        fi
    fi
}

set_as_entrance() {
    if [[ ! -f "${SCRIPT_FILE_PATH}" ]]; then
        wget --no-check-certificate -O ${SCRIPT_FILE_PATH} https://raw.githubusercontent.com/inipew/sbx-cfg/main/install.sh
        chmod +x ${SCRIPT_FILE_PATH}
    fi
}

#show sing-box status
show_status() {
    status_check
    case $? in
    0)
        show_sing_box_version
        echo -e "[INF] sing-box status: ${yellow}not running${plain}"
        show_enable_status
        LOGI "Configuration file path:${CONFIG_FILE_PATH}"
        LOGI "Executable file path:${BINARY_FILE_PATH}"
        ;;
    1)
        show_sing_box_version
        echo -e "[INF] sing-box status: ${green}running${plain}"
        show_enable_status
        show_running_status
        LOGI "Configuration file path:${CONFIG_FILE_PATH}"
        LOGI "Executable file path:${BINARY_FILE_PATH}"
        ;;
    255)
        echo -e "[INF] sing-box status: ${red}Not Installed${plain}"
        ;;
    esac
}

#show sing-box running status
show_running_status() {
    status_check
    if [[ $? == ${SING_BOX_STATUS_RUNNING} ]]; then
        local pid=$(pidof sing-box)
        local runTime=$(systemctl status sing-box | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        local memCheck=$(cat /proc/${pid}/status | grep -i vmrss | awk '{print $2,$3}')
        LOGI "##########################################"
        LOGI "ProcessID:${pid}"
        LOGI "Running time：${runTime}"
        LOGI "Memory usage:${memCheck}"
        LOGI "##########################################"
    else
        LOGE "sing-box not running"
    fi
}

#show sing-box version
show_sing_box_version() {
    LOGI "Version Information:$(${BINARY_FILE_PATH} version)"
}

#show sing-box enable status,enabled means sing-box can auto start when system boot on
show_enable_status() {
    local temp=$(systemctl is-enabled sing-box)
    if [[ x"${temp}" == x"enabled" ]]; then
        echo -e "[INF] Auto start sing-box when system boot: ${green}yes${plain}"
    else
        echo -e "[INF] Auto start sing-box when system boot: ${red}no${plain}"
    fi
}

#installation path create & delete,1->create,0->delete
create_or_delete_path() {

    if [[ $# -ne 1 ]]; then
        LOGE "invalid input,should be one paremete,and can be 0 or 1"
        exit 1
    fi
    if [[ "$1" == "1" ]]; then
        LOGI "Will create ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} for sing-box..."
        rm -rf ${DOWNLAOD_PATH} ${CONFIG_FILE_PATH}
        mkdir -p ${DOWNLAOD_PATH} ${CONFIG_FILE_PATH}
        if [[ $? -ne 0 ]]; then
            LOGE "create ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} for sing-box failed"
            exit 1
        else
            LOGI "create ${DOWNLAOD_PATH} adn ${CONFIG_FILE_PATH} for sing-box success"
        fi
    elif [[ "$1" == "0" ]]; then
        LOGI "Will delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH}..."
        rm -rf ${DOWNLAOD_PATH} ${CONFIG_FILE_PATH}
        if [[ $? -ne 0 ]]; then
            LOGE "delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} failed"
            exit 1
        else
            LOGI "delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} success"
        fi
    fi

}

#install some common utils
install_base() {
    if [[ ${OS_RELEASE} == "ubuntu" || ${OS_RELEASE} == "debian" ]]; then
        apt install wget tar jq -y
    elif [[ ${OS_RELEASE} == "centos" ]]; then
        yum install wget tar jq -y
    fi
}

#download sing-box  binary
download_sing-box() {
    LOGD "start downloading sing-box..."
    os_check && arch_check && install_base
    if [[ $# -gt 1 ]]; then
        echo -e "${red}invalid input,plz check your input: $* ${plain}"
        exit 1
    elif [[ $# -eq 1 ]]; then
        SING_BOX_VERSION=$1
        local SING_BOX_VERSION_TEMP="v${SING_BOX_VERSION}"
    else
        local SING_BOX_VERSION_TEMP=$(curl -Ls "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        SING_BOX_VERSION=${SING_BOX_VERSION_TEMP:1}
    fi
    LOGI "Version:${SING_BOX_VERSION}"
    local DOWANLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${SING_BOX_VERSION_TEMP}/sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz"

    #here we need create directory for sing-box
    create_or_delete_path 1
    wget -N --no-check-certificate -O ${DOWNLAOD_PATH}/sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz ${DOWANLOAD_URL}

    if [[ $? -ne 0 ]]; then
        LOGE "Download sing-box failed,plz be sure that your network work properly and can access github"
        create_or_delete_path 0
        exit 1
    else
        LOGI "Download sing-box successfully"
    fi
}

#dwonload  config examples,this should be called when dowanload sing-box
download_config() {
    LOGD "start downloading sing-box Configuration Templates..."
    if [[ ! -d ${CONFIG_FILE_PATH} ]]; then
        mkdir -p ${CONFIG_FILE_PATH}
    fi
    for file in "${FILE_LIST[@]}"; do
        if [[ ! -f "${CONFIG_FILE_PATH}/${file}" ]]; then
            wget --no-check-certificate -O "${CONFIG_FILE_PATH}/${file}.json" "https://raw.githubusercontent.com/inipew/sbx-cfg/main/config/${file}.json"
            if [[ $? -ne 0 ]]; then
                LOGE "Failed to download the sing-box configuration template, please check the network"
                exit 1
            else
                LOGI "Download the sing-box configuration template successfully"
            fi
        else
            LOGI "${CONFIG_FILE_PATH}/${file} Already exists, no need to download again"
        fi
    done
    
}

#backup config，this will be called when update sing-box
backup_config() {
    LOGD "Start backing up the sing-box configuration file..."
    for file in "${FILE_LIST[@]}"; do
        if [[ ! -f "${CONFIG_FILE_PATH}/${file}" ]]; then
            LOGE "There are currently no configuration files to back up"
            return 0
        else
            mv ${CONFIG_FILE_PATH}/${file}.json ${CONFIG_BACKUP_PATH}/${file}.json.bak
        fi
    done
    LOGD "Backup sing-box configuration file completed"
}

#backup config，this will be called when update sing-box
restore_config() {
    LOGD "Start restoring the sing-box configuration file..."
    for file in "${FILE_LIST[@]}"; do
        if [[ ! -f "${CONFIG_FILE_PATH}/${file}" ]]; then
            LOGE "There are currently no configuration files to back up"
            return 0
        else
            mv ${CONFIG_FILE_PATH}/${file}.json.bak ${CONFIG_BACKUP_PATH}/${file}.json
        fi
    done
    LOGD "Restoring the sing-box configuration file is complete"
}

#install sing-box,in this function we will download binary,paremete $1 will be used as version if it's given
install_sing-box() {
    set_as_entrance
    LOGD "Start installing sing-box..."
    if [[ $# -ne 0 ]]; then
        download_sing-box $1
    else
        download_sing-box
    fi
    download_config
    if [[ ! -f "${DOWNLAOD_PATH}/sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz" ]]; then
        clear_sing_box
        LOGE "could not find sing-box packages,plz check dowanload sing-box whether suceess"
        exit 1
    fi
    cd ${DOWNLAOD_PATH}
    #decompress sing-box packages
    tar -xvf sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz && cd sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}

    if [[ $? -ne 0 ]]; then
        clear_sing_box
        LOGE "Failed to decompress the sing-box installation package, the script exited"
        exit 1
    else
        LOGI "Unzip the sing-box installation package successfully"
    fi

    #install sing-box
    install -m 755 sing-box ${BINARY_FILE_PATH}

    if [[ $? -ne 0 ]]; then
        LOGE "install sing-box failed,exit"
        exit 1
    else
        LOGI "install sing-box suceess"
    fi
    install_systemd_service && enable_sing-box && start_sing-box
    LOGI "The installation of sing-box is successful, and it has been started successfully"
}

#update sing-box
update_sing-box() {
    LOGD "Start updating sing-box..."
    if [[ ! -f "${SERVICE_FILE_PATH}" ]]; then
        LOGE "Currently the system does not have sing-box installed, please use the update command if sing-box is installed."
        show_menu
    fi
    #here we need back up config first,and then restore it after installation
    backup_config
    #get the version paremeter
    if [[ $# -ne 0 ]]; then
        install_sing-box $1
    else
        install_sing-box
    fi
    restore_config
    if ! systemctl restart sing-box; then
        LOGE "update sing-box failed,please check logs"
        show_menu
    else
        LOGI "update sing-box success"
    fi
}

clear_sing_box() {
    LOGD "Starting to remove sing-box..."
    create_or_delete_path 0 && rm -rf ${SERVICE_FILE_PATH} && rm -rf ${BINARY_FILE_PATH} && rm -rf ${SCRIPT_FILE_PATH}
    LOGD "Remove sing-box completed"
}

#uninstall sing-box
uninstall_sing-box() {
    LOGD "Start uninstalling sing-box..."
    pidOfsing_box=$(pidof sing-box)
    if [ -n ${pidOfsing_box} ]; then
        stop_sing-box
    fi
    clear_sing_box

    if [ $? -ne 0 ]; then
        LOGE "Failed to uninstall sing-box, please check the logs."
        exit 1
    else
        LOGI "Uninstalled sing-box successfully"
    fi
}

#install systemd service
install_systemd_service() {
    LOGD "Starting installation of the sing-box systemd service..."
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        rm -rf ${SERVICE_FILE_PATH}
    fi
    #create service file
    touch ${SERVICE_FILE_PATH}
    if [ $? -ne 0 ]; then
        LOGE "create service file failed,exit"
        exit 1
    else
        LOGI "create service file success..."
    fi
    cat >${SERVICE_FILE_PATH} <<EOF
[Unit]
Description=sing-box Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target
Wants=network.target
[Service]
Type=simple
ExecStart=${BINARY_FILE_PATH} run -C ${CONFIG_FILE_PATH}
Restart=on-failure
RestartSec=30s
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
    chmod 644 ${SERVICE_FILE_PATH}
    systemctl daemon-reload
    LOGD "Installation of sing-box systemd service successful"
}

#start sing-box
start_sing-box() {
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        systemctl start sing-box
        sleep 1s
        status_check
        if [ $? == ${SING_BOX_STATUS_NOT_RUNNING} ]; then
            LOGE "start sing-box service failed,exit"
            exit 1
        elif [ $? == ${SING_BOX_STATUS_RUNNING} ]; then
            LOGI "start sing-box service success"
        fi
    else
        LOGE "${SERVICE_FILE_PATH} does not exist,can not start service"
        exit 1
    fi
}

#restart sing-box
restart_sing-box() {
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        systemctl restart sing-box
        sleep 1s
        status_check
        if [ $? == 0 ]; then
            LOGE "restart sing-box service failed,exit"
            exit 1
        elif [ $? == 1 ]; then
            LOGI "restart sing-box service success"
        fi
    else
        LOGE "${SERVICE_FILE_PATH} does not exist,can not restart service"
        exit 1
    fi
}

#stop sing-box
stop_sing-box() {
    LOGD "Stopping the sing-box service..."
    status_check
    if [ $? == ${SING_BOX_STATUS_NOT_INSTALL} ]; then
        LOGE "sing-box did not install,can not stop it"
        exit 1
    elif [ $? == ${SING_BOX_STATUS_NOT_RUNNING} ]; then
        LOGI "sing-box already stoped,no need to stop it again"
        exit 1
    elif [ $? == ${SING_BOX_STATUS_RUNNING} ]; then
        if ! systemctl stop sing-box; then
            LOGE "stop sing-box service failed,plz check logs"
            exit 1
        fi
    fi
    LOGD "Stopping the sing-box service succeeded"
}

#enable sing-box will set sing-box auto start on system boot
enable_sing-box() {
    systemctl enable sing-box
    if [[ $? == 0 ]]; then
        LOGI "Setting up sing-box to boot up successfully"
    else
        LOGE "Failed to set sing-box to boot up itself"
    fi
}

#disable sing-box
disable_sing-box() {
    systemctl disable sing-box
    if [[ $? == 0 ]]; then
        LOGI "Canceling the sing-box boot-up was successful"
    else
        LOGE "Canceling sing-box boot-up failure"
    fi
}

#show logs
show_log() {
    status_check
    if [[ $? == ${SING_BOX_STATUS_NOT_RUNNING} ]]; then
        journalctl -u sing-box.service -e --no-pager -f
    else
        confirm "Confirm whether logging is enabled in the configuration, the default is enabled." "y"
        if [[ $? -ne 0 ]]; then
            LOGI "The log will be read from the console:"
            journalctl -u sing-box.service -e --no-pager -f
        else
            local tempLog=''
            read -p "Will read the log from the log file, please enter the path of the log file, directly enter will use the default path.": tempLog
            if [[ -n ${tempLog} ]]; then
                LOGI "Log file path:${tempLog}"
                if [[ -f ${tempLog} ]]; then
                    tail -f ${tempLog} -s 3
                else
                    LOGE "${tempLog} Does not exist, please check the configuration"
                fi
            else
                LOGI "Log file path:${DEFAULT_LOG_FILE_SAVE_PATH}"
                tail -f ${DEFAULT_LOG_FILE_SAVE_PATH} -s 3
            fi
        fi
    fi
}

#clear log,the paremter is log file path
clear_log() {
    local filePath=''
    if [[ $# -gt 0 ]]; then
        filePath=$1
    else
        read -p "Please enter the log file path": filePath
        if [[ ! -n ${filePath} ]]; then
            LOGI "The input log file path is invalid, the default file path will be used."
            filePath=${DEFAULT_LOG_FILE_SAVE_PATH}
        fi
    fi
    LOGI "The log path is:${filePath}"
    if [[ ! -f ${filePath} ]]; then
        LOGE "Failed to clear sing-box log file,${filePath} not available, please confirm"
        exit 1
    fi
    fileSize=$(ls -la ${filePath} --block-size=M | awk '{print $5}' | awk -F 'M' '{print$1}')
    if [[ ${fileSize} -gt ${DEFAULT_LOG_FILE_DELETE_TRIGGER} ]]; then
        rm $1 && systemctl restart sing-box
        if [[ $? -ne 0 ]]; then
            LOGE "Failed to clear sing-box log file"
        else
            LOGI "Clearing the sing-box log file was successful."
        fi
    else
        LOGI "The current log size is${fileSize}M,less than${DEFAULT_LOG_FILE_DELETE_TRIGGER}M,Will not clear"
    fi
}

#enable auto delete log，need file path as
enable_auto_clear_log() {
    LOGI "Setting up the sing-box to clear logs on a regular basis..."
    local disabled=false
    disabled=$(cat ${CONFIG_FILE_PATH}/00_log.json | jq .log.disabled | tr -d '"')
    if [[ ${disabled} == "true" ]]; then
        LOGE "If logging is not enabled on the current system, the script will be exited directly."
        exit 0
    fi
    local filePath=''
    if [[ $# -gt 0 ]]; then
        filePath=$1
    else
        filePath=$(cat ${CONFIG_FILE_PATH}/00_log.json | jq .log.output | tr -d '"')
    fi
    if [[ ! -f ${filePath} ]]; then
        LOGE "${filePath} Does not exist, failed to set sing-box timer to clear logs."
        exit 1
    fi
    crontab -l >/tmp/crontabTask.tmp
    echo "0 0 * * 6 sing-box clear ${filePath}" >>/tmp/crontabTask.tmp
    crontab /tmp/crontabTask.tmp
    rm /tmp/crontabTask.tmp
    LOGI "Setting sing-box to clear log ${filePath} on a regular basis succeeded."
}

#disable auto dlete log
disable_auto_clear_log() {
    crontab -l | grep -v "sing-box clear" | crontab -
    if [[ $? -ne 0 ]]; then
        LOGI "Failed to cancel sing-box timer clearing logs"
    else
        LOGI "Canceling the sing-box timer to clear the logs succeeded."
    fi
}

#enable bbr
enable_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh)
    echo ""
}

#for cert issue
ssl_cert_issue() {
    bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/BashScripts/main/SSLAutoInstall/SSLAutoInstall.sh)
}

#show help
show_help() {
    echo "sing-box-v${SING_BOX_YES_VERSION} Managing Script Usage: "
    echo "------------------------------------------"
    echo "sing-box              - Show shortcut menu (more features)"
    echo "sing-box start        - Start the sing-box service"
    echo "sing-box stop         - Stop sing-box service"
    echo "sing-box restart      - Restart the sing-box service"
    echo "sing-box status       - Viewing sing-box status"
    echo "sing-box enable       - Setting the sing-box to boot up"
    echo "sing-box disable      - Cancel sing-box boot-up"
    echo "sing-box log          - Viewing the sing-box log"
    echo "sing-box clear        - Clear the sing-box log"
    echo "sing-box update       - Updating the sing-box service"
    echo "sing-box install      - Installing the sing-box service"
    echo "sing-box uninstall    - Uninstalling the sing-box service"
    echo "------------------------------------------"
}

#show menu
show_menu() {
    echo -e "
  ${green}sing-box-v${SING_BOX_YES_VERSION} Management Scripts${plain}
  ${green}0.${plain} Exit Script
————————————————
  ${green}1.${plain} Installing the sing-box service
  ${green}2.${plain} Updating the sing-box service
  ${green}3.${plain} Uninstalling the sing-box service
  ${green}4.${plain} Start the sing-box service
  ${green}5.${plain} Stop sing-box service
  ${green}6.${plain} Restart the sing-box service
  ${green}7.${plain} Viewing sing-box status
  ${green}8.${plain} Viewing the sing-box log
  ${green}9.${plain} Clear the sing-box log
  ${green}A.${plain} Checking the sing-box configuration
————————————————
  ${green}B.${plain} Setting the sing-box to boot up
  ${green}C.${plain} Cancel sing-box boot-up
  ${green}D.${plain} Set sing-box to clear logs & reboot regularly
  ${green}E.${plain} Cancel sing-box timer to clear logs & reboot
————————————————
  ${green}F.${plain} 一Key to turn on bbr 
  ${green}G.${plain} 一Key to apply for an SSL certificate
 "
    show_status
    echo && read -p "Please enter your choice[0-G]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_sing-box && show_menu
        ;;
    2)
        update_sing-box && show_menu
        ;;
    3)
        uninstall_sing-box && show_menu
        ;;
    4)
        start_sing-box && show_menu
        ;;
    5)
        stop_sing-box && show_menu
        ;;
    6)
        restart_sing-box && show_menu
        ;;
    7)
        show_menu
        ;;
    8)
        show_log && show_menu
        ;;
    9)
        clear_log && show_menu
        ;;
    A)
        config_check && show_menu
        ;;
    B)
        enable_sing-box && show_menu
        ;;
    C)
        disable_sing-box && show_menu
        ;;
    D)
        enable_auto_clear_log
        ;;
    E)
        disable_auto_clear_log
        ;;
    F)
        enable_bbr && show_menu
        ;;
    G)
        ssl_cert_issue
        ;;
    *)
        LOGE "Please enter the correct option [0-G]"
        ;;
    esac
}

start_to_run() {
    set_as_entrance
    clear
    show_menu
}

main() {
    if [[ $# > 0 ]]; then
        case $1 in
        "start")
            start_sing-box
            ;;
        "stop")
            stop_sing-box
            ;;
        "restart")
            restart_sing-box
            ;;
        "status")
            show_status
            ;;
        "enable")
            enable_sing-box
            ;;
        "disable")
            disable_sing-box
            ;;
        "log")
            show_log
            ;;
        "clear")
            clear_log
            ;;
        "update")
            if [[ $# == 2 ]]; then
                update_sing-box $2
            else
                update_sing-box
            fi
            ;;
        "install")
            if [[ $# == 2 ]]; then
                install_sing-box $2
            else
                install_sing-box
            fi
            ;;
        "uninstall")
            uninstall_sing-box
            ;;
        *) show_help ;;
        esac
    else
        start_to_run
    fi
}

main $*
