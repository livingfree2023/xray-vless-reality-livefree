#!/bin/bash

# Constants and Configuration

readonly SCRIPT_VERSION="20250723" 
readonly LOG_FILE="nokey.log"
readonly URL_FILE="nokey.url"
#readonly DEFAULT_PORT=443
readonly DEFAULT_DOMAIN="learn.microsoft.com"
readonly GITHUB_URL="https://github.com/livingfree2023/xray-vless-reality-nokey"
readonly GITHUB_CMD="bash <(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-livefree/refs/heads/main/nokey.sh)"
readonly SERVICE_NAME="xray.service"
readonly SERVICE_NAME_ALPINE="xray"

readonly GITHUB_XRAY_OFFICIAL_SCRIPT_URL="https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh"
readonly GITHUB_XRAY_OFFICIAL_SCRIPT_ALPINE_URL="https://github.com/XTLS/Xray-install/raw/main/alpinelinux/install-release.sh"
readonly GITHUB_XRAY_OFFICIAL_SCRIPT="install-release.sh"


# Color definitions
readonly red='\e[91m'
readonly green='\e[92m'
readonly yellow='\e[93m'
readonly magenta='\e[95m'
readonly cyan='\e[96m'
readonly none='\e[0m'

# Initialize log2file file
echo > "$LOG_FILE"

# Helper functions
log2file() {
    echo -e "$1" >> "$LOG_FILE"
}

error() {
    echo -e "\n${red} $1 ${none}\n" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "\n${yellow} $1 ${none}\n" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Error: Please run as root / 错误: 请以root身份运行此脚本: ${red}sudo -i${none}"
        exit 1
    fi
}

detect_network_interfaces() {
    
    Public_IPv4=$(curl -4s -m 2 https://www.cloudflare.com/cdn-cgi/trace | awk -F= '/^ip=/{print $2}')
    Public_IPv6=$(curl -6s -m 2 https://www.cloudflare.com/cdn-cgi/trace | awk -F= '/^ip=/{print $2}')
    
    [[ -n "$Public_IPv4" ]] && IPv4="$Public_IPv4"
    [[ -n "$Public_IPv6" ]] && IPv6="$Public_IPv6"
    echo "Detected interface / 找到网卡: $Public_IPv4 $Public_IPv6" >> "$LOG_FILE"
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_shortid() {
    # Generate 8 random bytes and convert to hex
    head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

install_dependencies() {

    echo -n -e "${yellow}开始准备工作 / Starting Preparation ... ${none}" | tee -a "$LOG_FILE"

    #todo: "qrencode" should be a flag controlled feature
    local tools=("curl")
    local missing_tools=()
    local install_packages=()

    declare -A os_package_command=(
        [apt]="apt install -y"
        [yum]="yum install -y"
        [dnf]="dnf install -y"
        [pacman]="pacman -Sy --noconfirm"
        [apk]="apk add --no-cache"
        [zypper]="zypper install -y"
        [xbps-install]="xbps-install -Sy"
    )

    # Fallback detection using which
    if [[ -z "$manager" ]]; then
        for candidate in "${!os_package_command[@]}"; do
            if command -v "$candidate" >/dev/null 2>&1; then
                manager=$candidate
                log2file "found manager $manager in fallback"
                break
            fi
        done
    fi

    if [[ -z "$manager" ]]; then
        error "无法识别包管理器 / Cannot detect package manager"
        return 1
    fi

    local install_cmd="${os_package_command[$manager]}"

    # Check for missing tools
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log2file "$tool is missing"
            eval "$install_cmd" "$tool"  >> "$LOG_FILE" 2>&1
        fi
    done
    
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"

}

install_xray() {
    echo -n -e "${yellow}开始，安装XRAY / Install XRAY ... ${none}" | tee -a "$LOG_FILE"
    
    if [ "$ID" = "alpine" ] || [ "$ID_LIKE" = "alpine" ]; then
      log2file "Alpine OS: install xray"
      ash $GITHUB_XRAY_OFFICIAL_SCRIPT >> $LOG_FILE 2>&1
      rc-update add xray               >> $LOG_FILE 2>&1
      rc-service xray start            >> $LOG_FILE 2>&1
    else
      bash $GITHUB_XRAY_OFFICIAL_SCRIPT install >> "$LOG_FILE" 2>&1
    fi

    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"

}

uninstall_in_alpine() {
  rc-service xray stop        >> $LOG_FILE 2>&1
  rc-update del xray          >> $LOG_FILE 2>&1
  rm -rf "/usr/local/bin/xray"    >> $LOG_FILE 2>&1
  rm -rf "/usr/local/share/xray"  >> $LOG_FILE 2>&1
  rm -rf "/usr/local/etc/xray/"   >> $LOG_FILE 2>&1
  rm -rf "/var/log/xray/"         >> $LOG_FILE 2>&1
  rm -rf "/etc/init.d/xray"       >> $LOG_FILE 2>&1
}

uninstall_xray() {
# Check if geodata files exist and are recent (less than 1 week old)
    echo -n -e "${yellow}什么？要卸载重装？ / Force Reinstall ... ${none}" | tee -a "$LOG_FILE"
    
    if [ "$ID" = "alpine" ] || [ "$ID_LIKE" = "alpine" ]; then
      log2file "Alpine OS: uninstall xray"
      uninstall_in_alpine
    else
      bash $GITHUB_XRAY_OFFICIAL_SCRIPT remove --purge >> "$LOG_FILE" 2>&1
    fi 

    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"

}


enable_bbr() {
    echo -n -e "${yellow}最后，打开BBR / Finishing, Enabling BBR ... ${none}" | tee -a "$LOG_FILE"
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"

}

show_banner() {
    echo -e "      ___         ___         ___         ___               "
    echo -e "     /__/\\       /  /\\       /__/|       /  /\\        ___   "
    echo -e "     \\  \\:\\     /  /::\\     |  |:|      /  /:/_      /__/|  "
    echo -e "      \\  \\:\\   /  /:/\\:\\    |  |:|     /  /:/ /\\    |  |:|  "
    echo -e "  _____\\__\\:\\ /  /:/  \\:\\ __|  |:|    /  /:/ /:/_   |  |:|  "
    echo -e " /__/::::::::/__/:/ \\__\\:/__/\_|:|___/__/:/ /:/ /\\__|__|:|  "
    echo -e " \\  \\:\\~~\\~~\\\\  \\:\\ /  /:\\  \\:\\/:::::\\  \\:\\/:/ /:/__/::::\\  "
    echo -e "  \\  \\:\\  ~~~ \\  \\:\\  /:/ \\  \\::/~~~~ \\  \\::/ /:/   ~\\~~\\:\\ "
    echo -e "   \\  \\:\\      \\  \\:\\/:/   \\  \\:\\      \\  \\:\\/:/      \\  \\:\\"
    echo -e "    \\  \\:\\      \\  \\::/     \\  \\:\\      \\  \\::/        \\__\\/"
    echo -e "     \\__\\/       \\__\\/       \\__\\/       \\__\\/              "



    echo "项目地址，欢迎点点点点星 / STAR ME PLEEEEEAAAASE "
    echo -e "${cyan}$GITHUB_URL${none}"
    echo -e "本脚本支持带参数执行, 不带参数将直接无敌 / See ${cyan}--help${none} for parameters"

}

parse_args() {
    # Parse command line arguments
    for arg in "$@"; do
      case $arg in
        --help)
          show_help
          ;;
        --force)
          force_reinstall=1
          ;;
        --netstack=*)
          case "${arg#*=}" in
            4)
              netstack=4
              ip=${IPv4}
              ;;
            6)
              netstack=6
              ip=${IPv6}
              ;;
            *)
              error "错误: 无效的网络协议栈值 / Error: Invalid netstack value"
              show_help
              exit 1
              ;;
          esac
          ;;
        --port=*)
          port="${arg#*=}"
          ;;
        --domain=*)
          domain="${arg#*=}"
          ;;
        --uuid=*)
          uuid="${arg#*=}"
          ;;
        *)
          error "Unknown option / 什么鬼参数: $arg"
          show_help
          exit 1
          ;;
      esac
    done

}



configure_xray() {

    # Set default values if not specified
    if [[ -z $netstack ]]; then
      if [[ -n "$IPv4" ]]; then
        netstack=4
        ip=${IPv4}
      elif [[ -n "$IPv6" ]]; then
        netstack=6
        ip=${IPv6}
      else
        error "没有获取到公共IP / No public IP detected"
        exit 1
      fi
    fi
    
    log2file "使用ip $ip" 

    # 端口
    if [[ -z $port ]]; then      
      base=$((10000 + RANDOM % 50000))  # Start at a random offset
      for i in $(seq 0 1000); do
        port=$((base + i))
        nc -z 127.0.0.1 $port 2>/dev/null || {
          echo "$port" >> "$LOG_FILE"
          break
        }
      done
      log2file "找到一个空闲随机端口，如果有防火墙需要放行 / Random unused port found, if firewall enabled, add tcp rules for: ${cyan}$port${none}"
    fi

    # Xray UUID
    if [[ -z $uuid ]]; then
        uuid=$(generate_uuid)
    fi

    # x25519公私钥
    if [[ -z $private_key ]]; then
      # Generate keys using xray directly
      keys=$(xray x25519)
      private_key=$(echo "$keys" | awk '/Private key:/ {print $3}')
      public_key=$(echo "$keys" | awk '/Public key:/ {print $3}')
      log2file "私钥 (PrivateKey) = ${cyan}${private_key}${none}"
      log2file "公钥 (PublicKey) = ${cyan}${public_key}${none}" 
    fi

    # ShortID
    if [[ -z $shortid ]]; then
      shortid=$(generate_shortid)
      log2file "ShortID = ${cyan}${shortid}${none}" 
    fi

    # 目标网站
    if [[ -z $domain ]]; then
      [ -z "$domain" ] && domain="learn.microsoft.com"
      log2file "SNI = ${cyan}$domain${none}"
    fi

    log2file "网络栈netstack = ${cyan}${netstack}${none}" 
    log2file "本机IP = ${cyan}${ip}${none}"
    log2file "端口Port = ${cyan}${port}${none}" 
    log2file "用户UUID = $cyan${uuid}${none}" 
    log2file "域名SNI = ${cyan}$domain${none}" 


    # 配置config.json
    
    echo -n -e "${yellow}快好了，手搓 / Configuring /usr/local/etc/xray/config.json ... ${none}"
    cat > /usr/local/etc/xray/config.json <<-EOF
{ // VLESS + Reality
  "log2file": {
    "access": "/var/log2file/xray/access.log2file",
    "error": "/var/log2file/xray/error.log2file",
    "loglevel": "warning"
  },
  "inbounds": [
    // [inbound] 如果你想使用其它翻墙服务端如(HY2或者NaiveProxy)对接v2ray的分流规则, 那么取消下面一段的注释, 并让其它翻墙服务端接到下面这个socks 1080端口
    // {
    //   "listen":"127.0.0.1",
    //   "port":1080,
    //   "protocol":"socks",
    //   "sniffing":{
    //     "enabled":true,
    //     "destOverride":[
    //       "http",
    //       "tls"
    //     ]
    //   },
    //   "settings":{
    //     "auth":"noauth",
    //     "udp":false
    //   }
    // },
    {
      "listen": "0.0.0.0",
      "port": ${port},    // ***
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",    // ***
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${domain}:443",    // ***
          "xver": 0,
          "serverNames": ["${domain}"],    // ***
          "privateKey": "${private_key}",    // ***私钥
          "shortIds": ["${shortid}"]    // ***
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
// [outbound]
{
    "protocol": "freedom",
    "settings": {
        "domainStrategy": "UseIPv4"
    },
    "tag": "force-ipv4"
},
{
    "protocol": "freedom",
    "settings": {
        "domainStrategy": "UseIPv6"
    },
    "tag": "force-ipv6"
},
{
    "protocol": "socks",
    "settings": {
        "servers": [{
            "address": "127.0.0.1",
            "port": 40000 //warp socks5 port
        }]
    },
    "tag": "socks5-warp"
},
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "dns": {
    "servers": [
      "8.8.8.8",
      "1.1.1.1",
      "2001:4860:4860::8888",
      "2606:4700:4700::1111",
      "localhost"
    ]
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
// [routing-rule]
//{
//   "type": "field",
//   "domain": ["geosite:google", "geosite:openai"],  // ***
//   "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp
//},
//{
//   "type": "field",
//   "domain": ["geosite:cn"],  // ***
//   "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp // blocked
//},
//{
//   "type": "field",
//   "ip": ["geoip:cn"],  // ***
//   "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp // blocked
//},
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"
    # 重启 Xray
    echo -n -e "${yellow}冲刺，开启服务 / Starting Service ... ${none}"
    service xray restart >> "$LOG_FILE" 2>&1
    echo -e "[${green}OK${none}]" | tee -a  "$LOG_FILE"
}


# Function to display help message
show_help() {
  echo -e "当前版本 / Version: ${cyan}${SCRIPT_VERSION}${none} "
  echo "使用方法: $0 [options] / Usage"
  echo "选项: / Options"
  echo "  --netstack=4|6     使用IPv4或IPv6 (默认: 自动检测) / Use IPv4 or IPv6"
  echo "  --port=NUMBER      设置端口号 (默认: 随机) / Set port number"
  echo "  --domain=DOMAIN    设置SNI域名 (默认: learn.microsoft.com) / Set SNI domain"
  echo "  --uuid=STRING      设置UUID (默认: 自动生成) / Set UUID"
  echo "  --help             显示此帮助信息 / Show this help message"

  exit 0
}

output_results() {
    # 指纹FingerPrint
    fingerprint="random"
    # SpiderX
    spiderx=""

    log2file "地址 / Address = $cyan${ip}${none}"
    log2file "端口 / Port = ${cyan}${port}${none}"
    log2file "用户ID / User ID (UUID) = $cyan${uuid}${none}"
    log2file "流控 / Flow Control = ${cyan}xtls-rprx-vision${none}"
    log2file "加密 / Encryption = ${cyan}none${none}"
    log2file "传输协议 / Network Protocol = ${cyan}tcp${none}"
    log2file "伪装类型 / Header Type = ${cyan}none${none}"
    log2file "底层传输安全 / Transport Security = ${cyan}reality${none}"
    log2file "SNI = ${cyan}${domain}${none}"
    log2file "指纹 / Fingerprint = ${cyan}${fingerprint}${none}"
    log2file "公钥 / PublicKey = ${cyan}${public_key}${none}"
    log2file "ShortId = ${cyan}${shortid}${none}"
    log2file "SpiderX = ${cyan}${spiderx}${none}"

    if [[ $netstack == "6" ]]; then
      ip=[$ip]
    fi
    
    vless_reality_url="vless://${uuid}@${ip}:${port}?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=${domain}&fp=${fingerprint}&pbk=${public_key}&sid=${shortid}&spx=${spiderx}&#NOKEY_${ip}"

    log2file "${yellow}二维码生成命令: / For QR code, run: ${none}" 
    log2file "qrencode -t UTF8 -r $URL_FILE" | tee -a "$LOG_FILE"

    echo -e -n "${yellow}检查服务状态 / Checking Service ... ${none}" | tee -a "$LOG_FILE"

    if [ "$ID" = "alpine" ] || [ "$ID_LIKE" = "alpine" ]; then
      if rc-service "$SERVICE_NAME_ALPINE" status >/dev/null 2>&1; then 
          echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"
      else
        error "[服务未运行 / Service is not active]" 
        service status "$SERVICE_NAME_ALPINE" | tee -a "$LOG_FILE"
        error "运行详细记录在 $LOG_FILE / See complete logs"
        exit 1
      fi
    else
      if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"
      else
        error "服务未运行 / Service is not active" 
        systemctl status "$SERVICE_NAME" | tee -a "$LOG_FILE"
        error "运行详细记录在 $LOG_FILE / See complete logs"
        exit 1
      fi
    fi
    
    echo -e "${yellow}舒服了 / Done: ${none}" | tee -a "$LOG_FILE"

    echo -e "${magenta}"
    echo -e "${vless_reality_url}" | tee -a "$LOG_FILE" | tee "$URL_FILE"
    echo -e "${none}"
    

}

download_official_script() {

    # Download official script
    echo -n -e "${yellow}下载，官方脚本 / Download Official Script ... ${none}" | tee -a "$LOG_FILE"

    local url="$GITHUB_XRAY_OFFICIAL_SCRIPT_URL"

    if [ "$ID" = "alpine" ] || [ "$ID_LIKE" = "alpine" ]; then
        url="$GITHUB_XRAY_OFFICIAL_SCRIPT_ALPINE_URL"
        log2file "Alpine OS detected"        
    fi    

    curl -sL "$url" -o "$GITHUB_XRAY_OFFICIAL_SCRIPT" >> "$LOG_FILE" 2>&1
    if [[ -f "$GITHUB_XRAY_OFFICIAL_SCRIPT" ]]; then
        echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"
    else
        echo -e "[${red}FAILED${none}]" | tee -a "$LOG_FILE"
        error "无法下载官方脚本，检查互联网链接，详细查看$LOG_FILE"
        exit 1
    fi

}

# Main function
main() {
    SECONDS=0
    
    check_root
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        error "无法识别的OS / Cannot determine OS."
        exit 1
    fi

    show_banner
    install_dependencies # the next function needs curl, in debian 9 curl is not shipped
    download_official_script

    detect_network_interfaces
    parse_args "$@"
    
    if [[ $force_reinstall == 1 ]]; then
      uninstall_xray
    fi

    install_xray
    configure_xray
    enable_bbr
    output_results
    echo -e "${yellow}总用时 / Elapsed Time:${none}  ${cyan}$SECONDS 秒${none}"
    echo -e "---------- ${cyan}live free or die hard${none} -------------" | tee -a "$LOG_FILE"
}

main "$@"


