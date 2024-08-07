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
SING_BOX_YES_VERSION='0.3.0'

#package download path
DOWNLAOD_PATH='/usr/local/sing-box'

DOMAIN_CONFIG_FILE="/usr/local/etc/sing-box/domain"

#backup config path
CONFIG_BACKUP_PATH='/usr/local/etc'

#config install path
CONFIG_FILE_PATH='/usr/local/etc/sing-box/config'

#binary install path
BINARY_FILE_PATH='/usr/local/bin/sing-box'

#nginx config path
NGINX_CONFIG_PATH="/etc/nginx/conf.d/alone.conf"

#scritp install path
SCRIPT_FILE_PATH='/usr/local/sbin/sing-box'

#service install path
SERVICE_FILE_PATH='/etc/systemd/system/sing-box.service'

#log file save path
DEFAULT_LOG_FILE_SAVE_PATH='/usr/local/sing-box/sing-box.log'

FILE_LIST=(
    "00_log_and_dns.json"
    "01_outbounds_and_route.json"
    "02_vless_ws.json"
    "03_vmess_ws.json"
    "04_trojan_ws.json"
    "05_socks.json"
    "06_vless_hu.json"
    "07_vmess_hu.json"
    "08_trojan_hu.json"
)
ACCOUNT_FILE_LIST=(
        "02_vless_ws.json"
        "03_vmess_ws.json"
        "04_trojan_ws.json"
        "05_socks.json"
        "06_vless_hu.json"
        "07_vmess_hu.json"
        "08_trojan_hu.json"
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
        echo && read -p "$1 [Default $2]: " temp
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
    if [[ ! -e "${CONFIG_FILE_PATH}" ]]; then
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
        LOGI "Configuration file path: ${CONFIG_FILE_PATH}"
        LOGI "Executable file path: ${BINARY_FILE_PATH}"
        ;;
    1)
        show_sing_box_version
        echo -e "[INF] sing-box status: ${green}running${plain}"
        show_enable_status
        show_running_status
        LOGI "Configuration file path: ${CONFIG_FILE_PATH}"
        LOGI "Executable file path: ${BINARY_FILE_PATH}"
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
        LOGI "ProcessID: ${pid}"
        LOGI "Running time：${runTime}"
        LOGI "Memory usage: ${memCheck}"
        LOGI "##########################################"
    else
        LOGE "sing-box not running"
    fi
}

#show sing-box version
show_sing_box_version() {
    LOGI "Version Information: $(${BINARY_FILE_PATH} version)"
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
create_config_file(){
    LOGD "Creating base config files"
    cat <<EOF >"${CONFIG_FILE_PATH}/00_log_and_dns.json"
{
  "log": {
    "level": "info",
    "output": "/usr/local/sing-box/sing-box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns_main",
        "address": "https://dns.google/dns-query",
        "address_resolver": "dns_local",
        "address_strategy": "prefer_ipv4",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "dns_second",
        "address": "https://cloudflare-dns.com/dns-query",
        "address_resolver": "dns_local",
        "address_strategy": "prefer_ipv4",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "dns_third",
        "address": "https://dns.quad9.net/dns-query",
        "address_resolver": "dns_local",
        "address_strategy": "prefer_ipv4",
        "strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "dns_local",
        "address": "local",
        "address_strategy": "prefer_ipv4",
        "detour": "direct"
      },
      {
        "tag": "block-dns",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "rule_set": "rule-malicious",
        "server": "block-dns",
        "disable_cache": true,
        "rewrite_ttl": 20
      },
      {
        "type": "logical",
        "mode": "and",
        "rules": [
          {
            "protocol": "quic"
          },
          {
            "rule_set": "youtube"
          }
        ],
        "server": "block-dns",
        "disable_cache": true,
        "rewrite_ttl": 20
      },
      {
        "type": "logical",
        "mode": "and",
        "rules": [
          {
            "outbound": "any"
          },
          {
            "rule_set": [
              "youtube",
              "google"
            ]
          }
        ],
        "server": "dns_main",
        "rewrite_ttl": 20
      },
      {
        "type": "logical",
        "mode": "and",
        "rules": [
          {
            "outbound": "any"
          },
          {
            "rule_set": "tiktok"
          }
        ],
        "server": "dns_second",
        "rewrite_ttl": 20
      },
      {
        "outbound": "any",
        "server": "dns_second",
        "rewrite_ttl": 20
      }
    ],
    "final":"dns_second",
    "reverse_mapping": true,
    "independent_cache": true
  },
  "ntp": {
    "server": "time.google.com",
    "server_port": 123,
    "interval": "5m0s",
    "detour": "direct"
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "caches.db",
      "cache_id": "sing"
    },
    "clash_api": {
      "external_controller": "0.0.0.0:9090",
      "external_ui": "dashboard",
      "external_ui_download_url": "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip",
      "external_ui_download_detour": "direct",
      "secret": "qwe12345",
      "default_mode": "Rule"
    }
  }
}
EOF

sleep 2

cat <<EOF >"${CONFIG_FILE_PATH}/01_outbounds_and_route.json"
{
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "selector",
      "tag": "TrafficAds",
      "outbounds": [
        "direct",
        "block"
      ],
      "default": "block"
    },
    {
      "type": "selector",
      "tag": "TrafficPorn",
      "outbounds": [
        "direct",
        "block"
      ],
      "default": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "type": "logical",
        "mode": "or",
        "rules": [
          {
            "domain_suffix": [
                "pikachu.my.id",
                "windows.net",
                "live.com"
            ]
          },
          {
            "domain_keyword": [
            "googlesyndication",
            "googleadservices",
            "appsflyer",
            "cftunnel",
            "argotunnel",
            "microsoftonline",
            "sharepoint",
            "openai",
            "zerotier",
            "shinigami",
            "apkomik",
            "komikav",
            "cdnkomik",
            "pojokmanga",
            "kiryuu",
            "komikcast",
            "mangatale",
            "cosmicscans",
            "hivescans",
            "manhwalist"
            ]
          },
          {
            "rule_set": [
            "onedrive",
            "microsoft",
            "openai"
            ]
          }
        ],
        "outbound": "direct"
      },
      {
        "type": "logical",
        "mode": "and",
        "rules": [
          {
            "protocol": "quic"
          },
          {
            "rule_set": "youtube"
          }
        ],
        "outbound": "block"
      },
      {
        "rule_set": [
          "oisd-full",
          "rule-ads",
          "d3ward"
        ],
        "outbound": "TrafficAds"
      },
      {
        "rule_set": [
          "oisd-nsfw",
          "category-porn"
        ],
        "outbound": "TrafficPorn"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "oisd-full",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-oisd-full.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "oisd-nsfw",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-oisd-nsfw.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "rule-ads",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-rule-ads.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "d3ward",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-d3ward.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "rule-malicious",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-rule-malicious.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "category-porn",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-category-porn.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "openai",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-openai.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "onedrive",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-onedrive.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "microsoft",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-microsoft.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "youtube",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-youtube.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "google",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-google.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "tiktok",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/malikshi/sing-box-geo/rule-set-geosite/geosite-tiktok.srs",
        "download_detour": "direct",
        "update_interval": "168h0m0s"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF
    create_account_file
}

create_account_file(){
    uuid=$(/usr/local/bin/sing-box generate uuid)
    LOGD "Creating config files"
    for file in "${ACCOUNT_FILE_LIST[@]}"; do
        case "${file}" in
        "02_vless_ws.json")
            cat <<EOF >${CONFIG_FILE_PATH}/${file}
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-ws-in",
      "listen": "0.0.0.0",
      "listen_port": 8001,
      "tcp_fast_open": true,
      "domain_strategy": "prefer_ipv4",
      "sniff": true,
      "sniff_timeout": "300ms",
      "users": [
        {
          "name": "default",
          "uuid": "${uuid}",
          "flow": ""
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "ws",
        "path": "/vless",
        "max_early_data": 0,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ]
}
EOF
            ;;
        "03_vmess_ws.json")
            cat <<EOF >${CONFIG_FILE_PATH}/${file}
{
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-ws-in",
      "listen": "0.0.0.0",
      "listen_port": 8002,
      "tcp_fast_open": true,
      "domain_strategy": "prefer_ipv4",
      "sniff": true,
      "sniff_timeout": "300ms",
      "users": [
        {
          "name": "default",
          "uuid": "${uuid}",
          "alterId": 0
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "ws",
        "path": "/vmess",
        "max_early_data": 0,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ]
}
EOF
            ;;
        "04_trojan_ws.json")
            cat <<EOF >${CONFIG_FILE_PATH}/${file}
{
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-ws-in",
      "listen": "0.0.0.0",
      "listen_port": 8003,
      "tcp_fast_open": true,
      "domain_strategy": "prefer_ipv4",
      "sniff": true,
      "sniff_timeout": "300ms",
      "users": [
        {
          "name": "default",
          "password": "${uuid}"
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "ws",
        "path": "/trojan",
        "max_early_data": 0,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ]
}
EOF
            ;;
        "05_socks.json")
            cat <<EOF >${CONFIG_FILE_PATH}/${file}
{
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
      "listen_port": 8093,
      "tcp_fast_open": true,
      "sniff": true,
      "sniff_timeout": "300ms",
      "domain_strategy": "prefer_ipv4",
      "users": [
        {
          "username": "${uuid}",
          "password": "${uuid}"
        }
      ]
    }
  ]
}
EOF
            ;;
        "06_vless_hu.json")
            cat <<EOF >${CONFIG_FILE_PATH}/${file}
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-hu-in",
      "listen": "0.0.0.0",
      "listen_port": 8004,
      "tcp_fast_open": true,
      "sniff": true,
      "sniff_timeout": "300ms",
      "domain_strategy": "prefer_ipv4",
      "users": [
        {
          "name": "default",
          "uuid": "${uuid}",
          "flow": ""
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "httpupgrade",
        "path": "/vless"
      }
    }
  ]
}
EOF
            ;;
        "07_vmess_hu.json")
            cat <<EOF >${CONFIG_FILE_PATH}/${file}
{
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-hu-in",
      "listen": "0.0.0.0",
      "listen_port": 8005,
      "tcp_fast_open": true,
      "sniff": true,
      "sniff_timeout": "300ms",
      "domain_strategy": "prefer_ipv4",
      "users": [
        {
          "name": "default",
          "uuid": "${uuid}",
          "alterId": 0
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "httpupgrade",
        "path": "/vmess"
      }
    }
  ]
}

EOF
            ;;
        "08_trojan_hu.json")
            cat <<EOF >${CONFIG_FILE_PATH}/${file}
{
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-hu-in",
      "listen": "0.0.0.0",
      "listen_port": 8006,
      "tcp_fast_open": true,
      "sniff": true,
      "sniff_timeout": "300ms",
      "domain_strategy": "prefer_ipv4",
      "users": [
        {
          "name": "default",
          "password": "${uuid}"
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "httpupgrade",
        "path": "/trojan"
      }
    }
  ]
}
EOF
            ;;
        *)
            echo "Unknown configuration file: ${file}"
            ;;
        esac
    done
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
        apt install wget tar jq moreutils -y
    elif [[ ${OS_RELEASE} == "centos" ]]; then
        yum install wget tar jq moreutils -y
    fi
}

#download sing-box  binary
download_sing_box() {
    local prereleaseStatus=false
    LOGD "start downloading sing-box..."
    os_check && arch_check && install_base
    if [[ $# -gt 1 ]]; then
        echo -e "${red}invalid input,plz check your input: $* ${plain}"
        exit 1
    elif [[ $# -eq 1 ]]; then
        if [[ "$1" == "1" ]]; then
            prereleaseStatus=true
            local SING_BOX_VERSION_TEMP=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
            SING_BOX_VERSION=${SING_BOX_VERSION_TEMP:1}
        else
            SING_BOX_VERSION=$1
            local SING_BOX_VERSION_TEMP="v${SING_BOX_VERSION}"
        fi
    else
        local SING_BOX_VERSION_TEMP=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
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

#backup config，this will be called when update sing-box
backup_restore_config() {
    if [[ "$1" == "1" ]]; then
        LOGD "Start backing up the sing-box configuration file..."
        for file in "${FILE_LIST[@]}"; do
            if [[ ! -f "${CONFIG_FILE_PATH}/${file}" ]]; then
                LOGE "There are currently no configuration files to back up"
                return 0
            else
                mv ${CONFIG_FILE_PATH}/${file} ${CONFIG_BACKUP_PATH}/${file}.bak
            fi
        done
        LOGD "Backup sing-box configuration file completed"
    elif [[ "$1" == "2" ]]; then
        LOGD "Start restoring the sing-box configuration file..."
        for file in "${FILE_LIST[@]}"; do
            if [[ ! -f "${CONFIG_FILE_PATH}/${file}" ]]; then
                LOGE "There are currently no configuration files to back up"
                return 0
            else
                mv ${CONFIG_BACKUP_PATH}/${file}.bak ${CONFIG_FILE_PATH}/${file}
            fi
        done
        LOGD "Restoring the sing-box configuration file is complete"
    fi
}

backup_nginx_config() {
    if [ -f "/etc/nginx/conf.d/alone.conf" ]; then
        backup_file="/etc/nginx/conf.d/alone.conf.bak"
        sudo cp ${NGINX_CONFIG_PATH} $backup_file
        echo "Backup konfigurasi Nginx ke $backup_file berhasil"
    else
        echo "Konfigurasi Nginx tidak ditemukan."
    fi

    show_nginx_menu
}

# Fungsi untuk membuat konfigurasi Nginx baru
create_nginx_config() {

    cat <<'EOF' >"${NGINX_CONFIG_PATH}"
map $http_upgrade $connection_upgrade {
    default upgrade;
    ""      close;
}

map $remote_addr $proxy_forwarded_elem {
    ~^[0-9.]+$        "for=$remote_addr";
    ~^[0-9A-Fa-f:.]+$ "for=\"[$remote_addr]\"";
    default           "for=unknown";
}

map $http_forwarded $proxy_add_forwarded {
    "~^(,[ \\t]*)*([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*([ \\t]*,([ \\t]*([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*)?)*$" "$http_forwarded, $proxy_forwarded_elem";
    default "$proxy_forwarded_elem";
}

map $uri:$http_sec_websocket_key $backend_info {
    ~^/vless:(.+)$    "127.0.0.1:8001";
    ~^/vmess:(.+)$    "127.0.0.1:8002";
    ~^/trojan:(.+)$   "127.0.0.1:8003";
    ~^/vless:         "127.0.0.1:8004";
    ~^/vmess:         "127.0.0.1:8005";
    ~^/trojan:        "127.0.0.1:8006";
}

server {
    listen 80 so_keepalive=on;
    listen [::]:80 so_keepalive=on;
    listen 8080 so_keepalive=on;
    listen [::]:8080 so_keepalive=on;
    listen 8880 so_keepalive=on;
    listen [::]:8880 so_keepalive=on;
    listen 2052 so_keepalive=on;
    listen [::]:2052 so_keepalive=on;
    listen 2082 so_keepalive=on;
    listen [::]:2082 so_keepalive=on;
    listen 2086 so_keepalive=on;
    listen [::]:2086 so_keepalive=on;
    listen 2095 so_keepalive=on;
    listen [::]:2095 so_keepalive=on;

    server_name __DOMAIN__;

    client_header_buffer_size 10k;
    large_client_header_buffers 8 16k;
    keepalive_timeout 300s;
    
    location / {
        return 404;
    }

    location ~ ^/([^/]+)/(vless|vmess|trojan) {
        if ($http_upgrade != "websocket") {
            return 404;
        }
        rewrite ^/([^/]+)/(.*)$ /$2 break;
        
        proxy_pass http://$backend_info;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Mengatur timeout proxy
        # proxy_connect_timeout 15s;
        # proxy_read_timeout 3600s;
        # proxy_send_timeout 3600s;

        # Buffering untuk permintaan HTTP ke proxy
        # proxy_buffer_size 128k;
        # proxy_buffers 4 256k;
        # proxy_busy_buffers_size 256k;
        
        proxy_redirect off;
    }
}

server {
    listen 443 ssl so_keepalive=on;
    listen [::]:443 ssl so_keepalive=on;
    listen 8443 ssl so_keepalive=on;
    listen [::]:8443 ssl so_keepalive=on;
    listen 2053 ssl so_keepalive=on;
    listen [::]:2053 ssl so_keepalive=on;
    listen 2083 ssl so_keepalive=on;
    listen [::]:2083 ssl so_keepalive=on;
    listen 2087 ssl so_keepalive=on;
    listen [::]:2087 ssl so_keepalive=on;
    listen 2096 ssl so_keepalive=on;
    listen [::]:2096 ssl so_keepalive=on;
    http2 on;

    server_name __DOMAIN__;
 
    ssl_certificate /etc/v2ray-agent/tls/__DOMAIN__.crt;
    ssl_certificate_key /etc/v2ray-agent/tls/__DOMAIN__.key;
    ssl_session_timeout 50m;
    ssl_prefer_server_ciphers  on;
    ssl_session_cache       shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 valid=60s;
    resolver_timeout 2s;
    
    client_header_buffer_size 10k;
    large_client_header_buffers 8 16k;
    keepalive_timeout 300s;

    location / {
        return 404;
    }

    location ~ ^/([^/]+)/(vless|vmess|trojan) {
        if ($http_upgrade != "websocket") {
            return 404;
        }
        rewrite ^/([^/]+)/(.*)$ /$2 break;
        
        proxy_pass http://$backend_info;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Mengatur timeout proxy
        # proxy_connect_timeout 15s;
        # proxy_read_timeout 3600s;
        # proxy_send_timeout 3600s;

        # Buffering untuk permintaan HTTP ke proxy
        # proxy_buffer_size 128k;
        # proxy_buffers 4 256k;
        # proxy_busy_buffers_size 256k;
        
        proxy_redirect off;
    }
}
EOF

    # Prompt the user for the domain
    read -r -p "Enter your vps domain: " DOMAIN

    # Save the domain to a configuration file
    echo "DOMAIN=${DOMAIN}" > "${DOMAIN_CONFIG_FILE}"

    source "${DOMAIN_CONFIG_FILE}"

    # Replace __DOMAIN__ with the actual domain in the configuration file
    sed -i "s/__DOMAIN__/${DOMAIN}/g" "${NGINX_CONFIG_PATH}"

    echo "Konfigurasi Nginx untuk ${DOMAIN} telah dibuat."
    nginx -s reload
    systemctl restart nginx
    echo "Nginx berhasil direload."

    show_nginx_menu
}

#install sing-box,in this function we will download binary,paremete $1 will be used as version if it's given
install_sing_box() {
    set_as_entrance
    LOGD "Start installing sing-box..."
    if [[ $# -ne 0 ]]; then
        download_sing_box $1
    else
        download_sing_box
    fi
    
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
    create_config_file
    install_systemd_service && enable_sing_box && start_sing_box
    LOGI "The installation of sing-box is successful, and it has been started successfully"
}

#update sing-box
update_sing_box() {
    LOGD "Start updating sing-box..."
    if [[ ! -f "${SERVICE_FILE_PATH}" ]]; then
        LOGE "Currently the system does not have sing-box installed, please use the update command if sing-box is installed."
        show_menu
    fi
    #here we need back up config first,and then restore it after installation
    backup_restore_config 1
    #get the version paremeter
    if [[ $# -ne 0 ]]; then
        install_sing_box $1
    else
        install_sing_box
    fi
    backup_restore_config 2
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
uninstall_sing_box() {
    LOGD "Start uninstalling sing-box..."
    pidOfsing_box=$(pidof sing-box)
    if [ -n ${pidOfsing_box} ]; then
        stop_sing_box
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
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${BINARY_FILE_PATH} run -D /var/lib/sing-box -C ${CONFIG_FILE_PATH}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 ${SERVICE_FILE_PATH}
    systemctl daemon-reload
    LOGD "Installation of sing-box systemd service successful"
}

#start sing-box
start_sing_box() {
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
restart_sing_box() {
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
stop_sing_box() {
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
enable_sing_box() {
    systemctl enable sing-box
    if [[ $? == 0 ]]; then
        LOGI "Setting up sing-box to boot up successfully"
    else
        LOGE "Failed to set sing-box to boot up itself"
    fi
}

#disable sing-box
disable_sing_box() {
    systemctl disable sing-box
    if [[ $? == 0 ]]; then
        LOGI "Canceling the sing-box boot-up was successful"
    else
        LOGE "Canceling sing-box boot-up failure"
    fi
}
user_exists() {
    local name_to_check=$1
    local filepath=$2
    if jq --arg name "$name_to_check" '.inbounds[0].users | map(select(.name == $name)) | length > 0' "${filepath}" >/dev/null; then
        return 0
    else
        return 1
    fi
}

add_new_account(){
    read -r -p "Enter the name for the new user: " username

    read -r -p "Enter UUID [default=automatically generated]: " input_uuid
    if [[ -z "$input_uuid" ]]; then
        uuid=$(/usr/local/bin/sing-box generate uuid)
    else
        uuid=$input_uuid
    fi

    for file in "${ACCOUNT_FILE_LIST[@]}"; do
        if [[ ! -f "${CONFIG_FILE_PATH}/${file}" ]]; then
            LOGE "There are currently no ${CONFIG_FILE_PATH}/${file} configuration files"
            return 0
        else
            local result=$(jq --arg name "${username}" '.inbounds[0].users | map(select(.name == $name)) | length > 0' "${CONFIG_FILE_PATH}/${file}")
            if [[ $result == "false" ]]; then
                case "${file}" in
                "02_vless_ws.json")
                    jq --arg name "$username" --arg uuid "$uuid" '.inbounds[0].users += [{"name": $name, "uuid": $uuid}]' "${CONFIG_FILE_PATH}/${file}" | sponge "${CONFIG_FILE_PATH}/${file}"
                    ;;
                "03_vmess_ws.json")
                    jq --arg name "$username" --arg uuid "$uuid" '.inbounds[0].users += [{"name": $name, "uuid": $uuid,"alterId": 0}]' "${CONFIG_FILE_PATH}/${file}" | sponge "${CONFIG_FILE_PATH}/${file}"
                    ;;
                "04_trojan_ws.json")
                    jq --arg name "$username" --arg password "$uuid" '.inbounds[0].users += [{"name": $name, "password": $password}]' "${CONFIG_FILE_PATH}/${file}" | sponge "${CONFIG_FILE_PATH}/${file}"
                    ;;
                "05_socks.json")
                    jq --arg name "$username" --arg password "$username" '.inbounds[0].users += [{"username": $name, "password": $password}]' "${CONFIG_FILE_PATH}/${file}" | sponge "${CONFIG_FILE_PATH}/${file}"
                    ;;
                "06_vless_hu.json")
                    jq --arg name "$username" --arg uuid "$uuid" '.inbounds[0].users += [{"name": $name, "uuid": $uuid}]' "${CONFIG_FILE_PATH}/${file}" | sponge "${CONFIG_FILE_PATH}/${file}"
                    ;;
                "07_vmess_hu.json")
                    jq --arg name "$username" --arg uuid "$uuid" '.inbounds[0].users += [{"name": $name, "uuid": $uuid,"alterId": 0}]' "${CONFIG_FILE_PATH}/${file}" | sponge "${CONFIG_FILE_PATH}/${file}"
                    ;;
                "08_trojan_hu.json")
                    jq --arg name "$username" --arg password "$uuid" '.inbounds[0].users += [{"name": $name, "password": $password}]' "${CONFIG_FILE_PATH}/${file}" | sponge "${CONFIG_FILE_PATH}/${file}"
                    ;;
                *)
                    echo "Unknown configuration file: ${file}"
                    ;;
                esac
                echo -e "Account ${username} has successfully added to config ${file}."
            else
                echo "User ${username} already exists in the ${CONFIG_FILE_PATH}/${file}."
            fi
        fi
    done
    restart_sing_box
}

display_users() {
    echo "List of users:"
    jq -r '.inbounds[0].users | to_entries | map("\(.key + 1). \(.value.name)") | .[]' ${CONFIG_FILE_PATH}/02_vless_ws.json
}
delete_user() {
    selected_number=$1
    for file in "${ACCOUNT_FILE_LIST[@]}"; do
        if [[ ! -f "${CONFIG_FILE_PATH}/${file}" ]]; then
            LOGE "There are currently no ${CONFIG_FILE_PATH}/${file} configuration files"
            return 0
        else
            jq --argjson index "$selected_number" 'del(.inbounds[0].users[$index - 1]) | .inbounds[0].users |= map(select(. != null))' "${CONFIG_FILE_PATH}/${file}"|sponge "${CONFIG_FILE_PATH}/${file}"
        fi
    done
    restart_sing_box
}
remove_an_account(){
    display_users
    read -p "Enter the number of the user you want to delete: " selected_number
    if [[ $selected_number =~ ^[0-9]+$ ]]; then
        total_users=$(jq '.inbounds[0].users | length' "${CONFIG_FILE_PATH}/02_vless_ws.json")
        if ((selected_number >= 1 && selected_number <= total_users)); then
            delete_user "$selected_number"
            echo "User number $selected_number has been deleted."
        else
            echo "Invalid selection. Please choose a number between 1 and $total_users."
        fi
    else
        echo "Invalid input. Please enter a valid number."
    fi
}

select_user() {
  local json_file="$1"

  # Check if the file exists
  if [ ! -f "${json_file}" ]; then
    echo "Error: JSON file not found at ${json_file}"
    return 1
  fi

  local protocol=$(jq -r '.inbounds[0].type' "${json_file}")
  local user_list=""

  if [ "${protocol}" == "socks" ]; then
    user_list=($(jq -r '.inbounds[0].users[] | select(.username != null) | .username' "${json_file}"))
  else
    user_list=($(jq -r '.inbounds[0].users[] | select(.name != null) | .name' "${json_file}"))
  fi

  echo "Select a user:"
  for ((i = 0; i < ${#user_list[@]}; i++)); do
    echo "$((i + 1)): ${user_list[$i]}"
  done

  read -p "Enter the number (1-${#user_list[@]}): " selected_number

  if [[ $selected_number -ge 1 && $selected_number -le ${#user_list[@]} ]]; then
    local selected_user="${user_list[$((selected_number - 1))]}"
    generate_account_details "${json_file}" "${selected_user}" "${protocol}"
  else
    echo "Invalid selection. Please enter a number between 1 and ${#user_list[@]}."
  fi
}

generate_account_details() {
  source "${DOMAIN_CONFIG_FILE}"
  local json_file="$1"
  local selected_user="$2"
  local protocol="$3"

  # Check if the file exists
  if [ ! -f "${json_file}" ]; then
    echo "Error: JSON file not found at ${json_file}"
    return 1
  fi

  # Extracting values using jq for the selected user
  local remarks=""
  local id=""

  if [ "${protocol}" == "trojan" ]; then
    id=$(jq -r --arg user "${selected_user}" '.inbounds[0].users[] | select(.name == $user) | "\(.password)"' "${json_file}")
    remarks=$(jq -r --arg user "${selected_user}" '.inbounds[0].users[] | select(.name == $user) | "\(.name)"' "${json_file}")
  elif [ "${protocol}" == "socks" ]; then
    id=$(jq -r --arg user "${selected_user}" '.inbounds[0].users[] | select(.username == $user) | "\(.password)"' "${json_file}")
    remarks=$(jq -r --arg user "${selected_user}" '.inbounds[0].users[] | select(.username == $user) | "\(.username)"' "${json_file}")
  else
    id=$(jq -r --arg user "${selected_user}" '.inbounds[0].users[] | select(.name == $user) | "\(.uuid)"' "${json_file}")
    remarks=$(jq -r --arg user "${selected_user}" '.inbounds[0].users[] | select(.name == $user) | "\(.name)"' "${json_file}")
  fi

  local port_tls="443,2053,2083,2087,2096,8443"  # Cloudflare's HTTPS WebSocket for TLS
  local port_nontls="80,8080,8880,2052,2082,2086,2095"  # Cloudflare's HTTP WebSocket for non-TLS
  local network=$(jq -r '.inbounds[0].transport.type' "${json_file}")
  local path=$(jq -r '.inbounds[0].transport.path' "${json_file}")
  local socks_port=$(jq -r '.inbounds[0].listen_port' "${json_file}")
  local currentDefaultTLSPort=443
  local currentDefaultNTLSPort=80
  local currentPath="/${remarks}${path}"

  # Printing the result based on protocol
  echo "================================"
  echo "Details Account for ${selected_user}"
  echo "Protocol    : ${protocol}"
  echo "Remarks     : ${remarks}"
  echo "Domain      : ${DOMAIN}"
  if [ "${protocol}" == "socks" ]; then
    echo "Username    : ${id}"
  fi
  if [ "${protocol}" == "trojan" ] || [ "${protocol}" == "socks" ]; then
    echo "Password    : ${id}"
  else
    echo "UUID        : ${id}"
  fi
  if [ "${protocol}" != "socks" ]; then
    echo "Port TLS    : ${port_tls}"
    echo "Port NonTLS : ${port_nontls}"
    echo "Network     : ${network}"
    echo "Path        : /${remarks}${path}"
  fi

  echo ""
  # Output link generation
  if [ "${protocol}" == "vless" ]; then
    echo "Link ${protocol} TLS:"
    echo "vless://${id}@${DOMAIN}:${currentDefaultTLSPort}?encryption=none&security=tls&type=${network}&host=${DOMAIN}&sni=${DOMAIN}&fp=chrome&path=${currentPath}#${remarks}_${protocol}_${network}_tls"
    
    echo ""
    echo "Link ${protocol} nTLS:"
    echo "vless://${id}@${DOMAIN}:${currentDefaultNTLSPort}?encryption=none&security=none&type=${network}&host=${DOMAIN}&sni=${DOMAIN}&fp=chrome&path=${currentPath}#${remarks}_${protocol}_${network}_ntls"
  
  elif [ "${protocol}" == "vmess" ]; then
    vmesstls="vmess://$(create_vmess_link "${remarks}-${protocol}-${network}-TLS" "${DOMAIN}" "${currentDefaultTLSPort}" "${id}" "${network}" "${currentPath}" "tls")"
    vmessntls="vmess://$(create_vmess_link "${remarks}-${protocol}-${network}-nTLS" "${DOMAIN}" "${currentDefaultNTLSPort}" "${id}" "${network}" "${currentPath}" "none")"
    echo "Link ${protocol} TLS:"
    echo "${vmesstls}"
    echo ""
    echo "Link ${protocol} nTLS:"
    echo "${vmessntls}"
  elif [ "${protocol}" == "trojan" ]; then
    echo "Link ${protocol} TLS:"
    echo "trojan://${id}@${DOMAIN}:${currentDefaultTLSPort}?path=${currentPath}&security=tls&host=${DOMAIN}&type=${network}&sni=${DOMAIN}#${remarks}_${protocol}_${network}_tls"
    
    echo ""
    echo "Link ${protocol} nTLS:"
    echo "trojan://${id}@${DOMAIN}:${currentDefaultNTLSPort}?path=${currentPath}&security=none&host=${DOMAIN}&type=${network}&sni=${DOMAIN}#${remarks}_${protocol}_${network}_ntls"
  elif [ "${protocol}" == "socks" ]; then
    echo "Link ${protocol}"
    echo "https://t.me/socks?server=${DOMAIN}&port=${socks_port}&user=${remarks}&pass=${id}"
  fi
  echo ""
}

create_vmess_link() {
    local version="2"
    local ps=$1
    local domain=$2
    local port=$3
    local id=$4
    local net=$5
    local path=$6
    local tls=$7
    cat <<EOF | base64 -w 0
{
  "v": "$version",
  "ps": "$ps",
  "add": "$domain",
  "port": "$port",
  "id": "$id",
  "aid": "0",
  "net": "$net",
  "path": "$path",
  "type": "none",
  "host": "$domain",
  "tls": "${tls}"
}
EOF
}

convert_to_base64(){
  qrCodeBase64Default=$(echo -n $1 | base64 -w 0)
  qrCodeBase64Default="${qrCodeBase64Default// /}"
  echo "$qrCodeBase64Default"
}

select_json_file() {
  local selected_number
  echo "Select JSON file:"
  for ((i = 0; i < ${#ACCOUNT_FILE_LIST[@]}; i++)); do
    echo "$((i + 1)): ${ACCOUNT_FILE_LIST[$i]}"
  done

  read -p "Enter the number (1-7): " selected_number

  if [[ $selected_number -ge 1 && $selected_number -le 7 ]]; then
    local json_file="$CONFIG_FILE_PATH/${ACCOUNT_FILE_LIST[$((selected_number - 1))]}"
    select_user "${json_file}"
  else
    echo "Invalid selection. Please enter a number between 1 and 7."
  fi
}

#show logs
show_log() {
    status_check
    if [[ $? == ${SING_BOX_STATUS_NOT_RUNNING} ]]; then
        journalctl -u sing-box.service -e --no-pager -f
    else
        local disabled=$(cat ${CONFIG_FILE_PATH}/00_log_and_dns.json | jq .log.disabled | tr -d '"')

        if [[  ${disabled} == "true" ]]; then
            LOGI "Logging is not currently enabled, please check the configuration."
            exit 1
        else
            local filePath=$(cat ${CONFIG_FILE_PATH}/00_log_and_dns.json | jq .log.output | tr -d '"')
            if [[ ! -n ${filePath} || ! -f ${filePath} ]]; then
                LOGE "Log ${filePath} does not exist, failed to view sing-box logs"
                exit 1
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
    disabled=$(cat ${CONFIG_FILE_PATH}/00_log_and_dns.json | jq .log.disabled | tr -d '"')
    if [[ ${disabled} == "true" ]]; then
        LOGE "If logging is not enabled on the current system, the script will be exited directly."
        exit 0
    fi
    local filePath=''
    if [[ $# -gt 0 ]]; then
        filePath=$1
    else
        filePath=$(cat ${CONFIG_FILE_PATH}/00_log_and_dns.json | jq .log.output | tr -d '"')
    fi
    if [[ ! -f ${filePath} ]]; then
        LOGE "${filePath} Does not exist, failed to set sing-box timer to clear logs."
        exit 1
    fi
    crontab -l >/tmp/crontabTask.tmp
    echo "3 0 * * * sing-box clear ${filePath}" >>/tmp/crontabTask.tmp
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
    echo "sing-box add          - Add an account"
    echo "sing-box del          - Delete an account"
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
show_manageAccount(){
    echo "Account Management: "
    echo "------------------------------------------"
    echo -e "${green}0.${plain} Back"
    echo -e "${green}1.${plain} Add new user"
    echo -e "${green}2.${plain} Remove an user"
    echo -e "${green}3.${plain} View account detail"
    echo -e "${green}4.${plain} List User"
    echo "------------------------------------------"
    echo && read -p "Please enter your choice[0-4]: " num

    case "${num}" in
    0)
        show_menu
        ;;
    1)
        add_new_account && show_manageAccount
        ;;
    2)
        remove_an_account && show_manageAccount
        ;;
    3)
        select_json_file && show_manageAccount
        ;;
    4)
        display_users && show_manageAccount
        ;;
    *)
        LOGE "Please enter the correct option [0-3]"
        ;;
    esac
}
show_core_menu(){
    echo "Sing-box Core Management"
    echo "------------------------------------------"
    echo -e "${green}0.${plain} Back to Menu"
    echo -e "${green}1.${plain} Installing the sing-box service"
    echo -e "${green}2.${plain} Updating the sing-box service"
    echo -e "${green}3.${plain} Uninstalling the sing-box service"
    echo -e "${green}4.${plain} Start the sing-box service"
    echo -e "${green}5.${plain} Stop sing-box service"
    echo -e "${green}6.${plain} Restart the sing-box service"
    echo "------------------------------------------"
    echo && read -p "Please enter your choice[0-6]: " num

    case "${num}" in
    0)
        show_menu
        ;;
    1)
        install_sing_box && show_menu
        ;;
    2)
        update_sing_box && show_menu
        ;;
    3)
        uninstall_sing_box && show_menu
        ;;
    4)
        start_sing_box && show_menu
        ;;
    5)
        stop_sing_box && show_menu
        ;;
    6)
        restart_sing_box && show_menu
        ;;
    *)
        LOGE "Please enter the correct option [0-6]"
        ;;
    esac
}
show_log_menu(){
    echo "Sing-box Core Management"
    echo "------------------------------------------"
    echo -e "${green}0.${plain} Back to Menu"
    echo -e "${green}1.${plain} Show sing-box log"
    echo -e "${green}2.${plain} Clear sing-box log"
    echo -e "${green}3.${plain} Set sing-box to clear logs & reboot regularly"
    echo -e "${green}4.${plain} Cancel sing-box timer to clear logs & reboot"
    echo "------------------------------------------"
    echo && read -p "Please enter your choice[0-2]: " num

    case "${num}" in
    0)
        show_menu
        ;;
    1)
        show_log && show_menu
        ;;
    2)
        clear_log && show_menu
        ;;
    3)
        enable_auto_clear_log
        ;;
    4)
        disable_auto_clear_log
        ;;
    *)
        LOGE "Please enter the correct option [0-2]"
        ;;
    esac
}
show_boot_menu(){
    echo "Boot Menu"
    echo "------------------------------------------"
    echo -e "${green}0.${plain} Back to Menu"
    echo -e "${green}1.${plain} Setting the sing-box to boot up"
    echo -e "${green}2.${plain} Cancel sing-box boot-up"
    echo "------------------------------------------"
    echo && read -p "Please enter your choice[0-2]: " num

    case "${num}" in
    0)
        show_menu
        ;;
    1)
        enable_sing_box && show_menu
        ;;
    2)
        disable_sing_box && show_menu
        ;;
    *)
        LOGE "Please enter the correct option [0-2]"
        ;;
    esac
}
show_other_menu(){
    echo "Other Menu"
    echo "------------------------------------------"
    echo -e "${green}0.${plain} Back to Menu"
    echo -e "${green}1.${plain} Key to turn on bbr"
    echo -e "${green}2.${plain} Key to apply for an SSL certificate"
    echo -e "${green}3.${plain} Nginx menu"
    echo "------------------------------------------"
    echo && read -p "Please enter your choice[0-2]: " num

    case "${num}" in
    0)
        show_menu
        ;;
    1)
        enable_bbr && show_menu
        ;;
    2)
        ssl_cert_issue
        ;;
    3)
        show_nginx_menu
        ;;
    *)
        LOGE "Please enter the correct option [0-2]"
        ;;
    esac
}

#show nginx menu
show_nginx_menu() {
    echo "Nginx Menu"
    echo "------------------------------------------"
    echo -e "${green}0.${plain} Back to Menu"
    echo -e "${green}1.${plain} Backup Old Configuration"
    echo -e "${green}2.${plain} Apply New Configuration"
    echo "------------------------------------------"
    echo && read -p "Please enter your choice[0-2]: " num

    case "${num}" in
    0)
        show_menu
        ;;
    1)
        backup_nginx_config
        ;;
    2)
        create_nginx_config
        ;;
    *)
        LOGE "Please enter the correct option [0-2]"
        ;;
    esac
}

#show menu
show_menu() {
    echo -e "${green}sing-box-v${SING_BOX_YES_VERSION} Management Scripts${plain}"
    echo -e "${green}0.${plain} Exit Script"
    echo "------------------------------------------"
    echo -e "${green}1.${plain} Core Management"
    echo -e "${green}2.${plain} Viewing sing-box status"
    echo -e "${green}3.${plain} View sing-box log"
    echo -e "${green}4.${plain} Account Management"
    echo "------------------------------------------"
    echo -e "${green}5.${plain} Checking the sing-box configuration"
    echo -e "${green}6.${plain} Show boot menu"
    echo -e "${green}7.${plain} Show Other Menu"
    echo "------------------------------------------"
    show_status
    echo && read -p "Please enter your choice[0-7]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        show_core_menu
        ;;
    2)
        show_menu
        ;;
    3)
        show_log_menu
        ;;
    4)
        show_manageAccount
        ;;
    5)
        config_check && show_menu
        ;;
    6)
        show_boot_menu
        ;;
    7)
        show_other_menu
        ;;
    *)
        LOGE "Please enter the correct option [0-7]"
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
            start_sing_box
            ;;
        "stop")
            stop_sing_box
            ;;
        "restart")
            restart_sing_box
            ;;
        "status")
            show_status
            ;;
        "enable")
            enable_sing_box
            ;;
        "disable")
            disable_sing_box
            ;;
        "log")
            show_log
            ;;
        "clear")
            clear_log $2
            ;;
        "add")
            add_new_account
            ;;
        "del")
            remove_an_account
            ;;
        "update")
            if [[ $# == 2 ]]; then
                update_sing_box $2
            else
                update_sing_box
            fi
            ;;
        "install")
            if [[ $# == 2 ]]; then
                install_sing_box $2
            else
                install_sing_box
            fi
            ;;
        "uninstall")
            uninstall_sing_box
            ;;
        *) show_help ;;
        esac
    else
        start_to_run
    fi
}

main $*