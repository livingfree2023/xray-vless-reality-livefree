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
    #InFaces=($(ls /sys/class/net/ | grep -E '^(eth|ens|eno|esp|enp|venet|vif)'))
    #for i in "${InFaces[@]}"; do
        # Public_IPv4=$(curl -4s --interface "$i" -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")
        # Public_IPv6=$(curl -6s --interface "$i" -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")
    
        Public_IPv4=$(curl -4s -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")
        Public_IPv6=$(curl -6s -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")
        
        [[ -n "$Public_IPv4" ]] && IPv4="$Public_IPv4"
        [[ -n "$Public_IPv6" ]] && IPv6="$Public_IPv6"
      echo "Detected interface / 找到网卡: $Public_IPv4 $Public_IPv6" >> "$LOG_FILE"
    #done
    
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_shortid() {
    # Generate 8 random bytes and convert to hex
    head -c 8 /dev/urandom | xxd -p
}

install_dependencies() {
    local tools=("curl" "jq" "qrencode" "lsof")
    local missing_tools=()

    # Detect OS type
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os=$ID
    else
        error "无法识别操作系统 / Cannot detect OS"
        return 1
    fi

    # Check for each tool
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -eq 0 ]; then
        echo -e "${yellow}工具链检查 / Tool check ... ${none}[${green}OK${none}]" | tee -a "$LOG_FILE"
        return 0
    fi

    echo -n -e "${yellow}开始准备工作 / Starting preparation ... ${none}" | tee -a "$LOG_FILE"

    # Install based on OS
    case "$os" in
        debian|ubuntu)
            apt update >> "$LOG_FILE" 2>&1
            apt install -y "${missing_tools[@]}" net-tools >> "$LOG_FILE" 2>&1
            ;;
        centos|fedora|rhel)
            yum install -y "${missing_tools[@]}" net-tools >> "$LOG_FILE" 2>&1
            ;;
        arch)
            pacman -Sy --noconfirm "${missing_tools[@]}" >> "$LOG_FILE" 2>&1
            ;;
        alpine)
            apk add --no-cache "${missing_tools[@]}" >> "$LOG_FILE" 2>&1
            ;;
        *)
            log2file "不支持的操作系统 / Unsupported OS: $os"
            return 1
            ;;
    esac
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"
}


install_xray() {
    echo -n -e "${yellow}开始，安装XRAY / Install XRAY ... ${none}" | tee -a "$LOG_FILE"
    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> "$LOG_FILE" 2>&1
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"

    echo -n -e "${yellow}加速，更新geodata / Updating geodata ... ${none}" | tee -a "$LOG_FILE"

    # Check if geodata files exist and are recent (less than 1 week old)
    local geoip="/usr/local/share/xray/geoip.dat"
    local geosite="/usr/local/share/xray/geosite.dat"
    week_ago=$(date -d "-7 days" +%s)

    if [[ -f "$geoip" && -f "$geosite" ]] && \
       [[ $(stat -c %Y "$geoip") -gt $week_ago ]] && \
       [[ $(stat -c %Y "$geosite") -gt $week_ago ]]; then
        log2file "${green}Geodata files are up to date, skip download / geodata文件已存在，跳过下载节省鸡流${none}"
        log2file "如果要更新geodata文件，请删除 /usr/local/share/xray/geoip.dat 和 /usr/local/share/xray/geosite.dat 然后重新运行脚本"
        log2file "To force download geodata, rm /usr/local/share/xray/geoip.dat /usr/local/share/xray/geosite.dat and run the script again"
    else
        bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata >> "$LOG_FILE" 2>&1
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

    # 端口
    if [[ -z $port ]]; then
      while true; do
        # Generate random port between 10000-65535
        port=$(shuf -i 10000-65535 -n 1)
        # Check if port is in use
        if ! lsof -i :$port > /dev/null 2>&1; then
          break
        fi
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
    service xray restart
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

output_results(){
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
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"
    else
      error "服务未运行 / Service is not active" 
      systemctl status "$SERVICE_NAME" | tee -a "$LOG_FILE"
      error "运行详细记录在 $LOG_FILE / See complete logs"
      exit 1
    fi

    
    echo -e "${yellow}舒服了 / Done: ${none}" | tee -a "$LOG_FILE"

    echo -e "${magenta}"
    echo -e "${vless_reality_url}" | tee -a "$LOG_FILE" | tee "$URL_FILE"
    echo -e "${none}"
    

}
# Main function
main() {
    SECONDS=0
    check_root    
    show_banner
    detect_network_interfaces
    parse_args "$@"
    install_dependencies
    install_xray
    configure_xray
    enable_bbr
    output_results
    echo -e "${yellow}总用时 / Elapsed Time:${none}  ${cyan}$SECONDS 秒${none}"
    echo -e "---------- ${cyan}live free or die hard${none} -------------" | tee -a "$LOG_FILE"
}

main "$@"


