#!/bin/bash

# Constants and Configuration
readonly LOG_FILE="0key.log"
readonly URL_FILE="0key.url"
readonly DEFAULT_PORT=443
readonly DEFAULT_DOMAIN="learn.microsoft.com"
readonly GITHUB_URL="https://github.com/livingfree2023/xray-vless-reality-livefree"
readonly GITHUB_CMD="bash <(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-livefree/refs/heads/main/0key.sh)"

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
    local uuid=$(cat /proc/sys/kernel/random/uuid)
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
        error "Cannot detect OS / 无法识别操作系统"
        return 1
    fi

    # Check for each tool
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -eq 0 ]; then
        echo -e "${yellow}Tool check  / 工具链检查 ... ${none}[${green}OK${none}]" | tee -a "$LOG_FILE"
        return 0
    fi

    echo -n -e "${yellow}Starting preparation... / 开始准备工作 ... ${none}" | tee -a "$LOG_FILE"

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
            log2file "Unsupported OS: $os / 不支持的操作系统"
            return 1
            ;;
    esac
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"
}


install_xray() {
    echo -n -e "${yellow}Xray installation... / 开始，Xray官方脚本安装...${none}" | tee -a "$LOG_FILE"
    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> "$LOG_FILE" 2>&1
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"

    echo -n -e "${yellow}Updating geodata... / 加速，更新geodata...${none}" | tee -a "$LOG_FILE"
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

generate_keys() {
    local uuid="$1"
    local private_key=$(echo -n "${uuid}" | md5sum | head -c 32 | base64 -w 0 | tr '+/' '-_' | tr -d '=')
    local tmp_key=$(echo -n "${private_key}" | xargs xray x25519 -i)
    # echo "$(echo ${tmp_key} | awk '{print $3}')" # private key
    # echo "$(echo ${tmp_key} | awk '{print $6}')" # public key
    # echo "$(echo -n ${uuid} | sha1sum | head -c 16)" # shortid
}

enable_bbr() {
    echo -n -e "${yellow}Finishing, Enabling BBR / 撞线，打开BBR ...${none}" | tee -a "$LOG_FILE"
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "[${green}OK${none}]" | tee -a "$LOG_FILE"

}

show_banner() {
  echo "                                                            "
  echo "██╗     ██╗██╗   ██╗███████╗███████╗██████╗ ███████╗███████╗" 
  echo "██║     ██║██║   ██║██╔════╝██╔════╝██╔══██╗██╔════╝██╔════╝"
  echo "██║     ██║██║   ██║█████╗  █████╗  ██████╔╝█████╗  █████╗  "
  echo "██║     ██║╚██╗ ██╔╝██╔══╝  ██╔══╝  ██╔══██╗██╔══╝  ██╔══╝  "
  echo "███████╗██║ ╚████╔╝ ███████╗██║     ██║  ██║███████╗███████╗"
  echo "╚══════╝╚═╝  ╚═══╝  ╚══════╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝"
  echo "                                                            "
  echo -e "${cyan}https://github.com/livingfree2023/xray-vless-reality-livefree${none} "
  echo "This script supports parameter execution see --help / 本脚本支持带参数执行, 不带参数将直接无敌"
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
              error "Error: Invalid netstack value / 错误: 无效的网络协议栈值"
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
        error "No public IP detected / 没有获取到公共IP"
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
      log2file "Random unused port found / 找到一个空闲随机端口 $port"
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
      log2file "${yellow} 私钥 (PrivateKey) = ${cyan}${private_key}${none}"
      log2file "${yellow} 公钥 (PublicKey) = ${cyan}${public_key}${none}" 
    fi

    # ShortID
    if [[ -z $shortid ]]; then
      shortid=$(generate_shortid)
      log2file "${yellow} ShortID = ${cyan}${shortid}${none}" 
    fi

    # 目标网站
    if [[ -z $domain ]]; then
      log2file "Preparing domain / 准备 ${magenta}域名${none}" 
      [ -z "$domain" ] && domain="learn.microsoft.com"
      log2file "${yellow} SNI = ${cyan}$domain${none}"
    fi

    log2file "${yellow} 网络栈netstack = ${cyan}${netstack}${none}" 
    log2file "${yellow} 本机IP = ${cyan}${ip}${none}"
    log2file "${yellow} 端口Port = ${cyan}${port}${none}" 
    log2file "${yellow} 用户UUID = $cyan${uuid}${none}" 
    log2file "${yellow} 域名SNI = ${cyan}$domain${none}" 


    # 配置config.json
    
    echo -n -e "${yellow}Configuring / 配置 /usr/local/etc/xray/config.json ...${none}"
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
    echo -n -e "${yellow}Restarting Xray / 重启 Xray${none}..."
    service xray restart
    echo -e "[${green}OK${none}]" | tee -a  "$LOG_FILE"
}


# Function to display help message
show_help() {
  # Get version from git commit date
  version="20250723" 
  echo -e "${yellow}Version / 版本: ${cyan}${version}${none}"
  echo "Usage / 使用方法: $0 [options]"
  echo "Options / 选项:"
  echo "  --netstack=4|6     Use IPv4 or IPv6 / 使用IPv4或IPv6 (默认: 自动检测)" 
  echo "  --port=NUMBER      Set port number / 设置端口号 (默认: 随机)"
  echo "  --domain=DOMAIN    Set SNI domain / 设置SNI域名 (默认: learn.microsoft.com)"
  echo "  --uuid=STRING      Set UUID / 设置UUID (默认: 自动生成)"
  echo "  --help            Show this help message / 显示此帮助信息"
  exit 0
}

output_results(){
    # 指纹FingerPrint
    fingerprint="random"
    # SpiderX
    spiderx=""

    echo -e "${green}[All Done! / 大功告成！]${none}" | tee -a "$LOG_FILE"
    log2file  "Address / 地址 = $cyan${ip}${none}" 
    log2file  "Port / 端口 = ${cyan}${port}${none}" 
    log2file  "User ID (UUID) / 用户ID = $cyan${uuid}${none}"
    log2file  "Flow Control / 流控 = ${cyan}xtls-rprx-vision${none}" 
    log2file  "Encryption / 加密 = ${cyan}none${none}" 
    log2file  "Network Protocol / 传输协议 = ${cyan}tcp${none}" 
    log2file  "Header Type / 伪装类型 = ${cyan}none${none}" 
    log2file  "Transport Security / 底层传输安全 = ${cyan}reality${none}"
    log2file  "SNI = ${cyan}${domain}${none}" 
    log2file  "Fingerprint / 指纹 = ${cyan}${fingerprint}${none}" 
    log2file  "PublicKey / 公钥 = ${cyan}${public_key}${none}"
    log2file  "ShortId = ${cyan}${shortid}${none}"
    log2file  "SpiderX = ${cyan}${spiderx}${none}" 
    if [[ $netstack == "6" ]]; then
      ip=[$ip]
    fi
    vless_reality_url="vless://${uuid}@${ip}:${port}?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=${domain}&fp=${fingerprint}&pbk=${public_key}&sid=${shortid}&spx=${spiderx}&#VLESS_R_${ip}"

    echo "For QR code, run / 如果需要二维码，复制以下命令" | tee -a "$LOG_FILE"
    echo "qrencode -t UTF8 -r 0key.url" | tee -a "$LOG_FILE"
    echo "Node information saved in / 链接存在 0key.url, complete logs / 运行详细记录在 $LOG_FILE" | tee -a "$LOG_FILE"
        
    echo -e "Your link / 你的链接: " | tee -a "$LOG_FILE"
    echo -e "${cyan}"
    echo -e "${vless_reality_url}" | tee -a "$LOG_FILE" | tee "$URL_FILE"
    echo -e "${none}"
    echo "---------- Live Free & Fight Autocracy -------------" | tee -a "$LOG_FILE"

}
# Main function
main() {
    check_root
    show_banner
    detect_network_interfaces
    
    parse_args "$@"
    
    install_dependencies
    install_xray

    configure_xray
    enable_bbr

    output_results
}

main "$@"


