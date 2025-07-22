#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请以root身份运行此脚本"
    echo -e "请先执行 sudo -i 后执行 \nbash <(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-livefree/refs/heads/main/install.sh)"
    exit 1
fi

red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

error() {
    echo -e "\n$red 输入错误! ${none}\n"
}

warn() {
    echo -e "\n${yellow} $1 ${none}\n"
}

# Remove pause function or modify it to do nothing
pause() {
    return 0
}

# 说明


echo "██╗     ██╗██╗   ██╗███████╗███████╗██████╗ ███████╗███████╗";
echo "██║     ██║██║   ██║██╔════╝██╔════╝██╔══██╗██╔════╝██╔════╝";
echo "██║     ██║██║   ██║█████╗  █████╗  ██████╔╝█████╗  █████╗  ";
echo "██║     ██║╚██╗ ██╔╝██╔══╝  ██╔══╝  ██╔══██╗██╔══╝  ██╔══╝  ";
echo "███████╗██║ ╚████╔╝ ███████╗██║     ██║  ██║███████╗███████╗";
echo "╚══════╝╚═╝  ╚═══╝  ╚══════╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝";
echo "                                                            ";
echo -e "${cyan}https://github.com/livingfree2023/xray-vless-reality-livefree${none} "
echo -e "本脚本支持带参数执行, 不带参数将直接无敌"



# 本机 IP
InFaces=($(ls /sys/class/net/ | grep -E '^(eth|ens|eno|esp|enp|venet|vif)'))

for i in "${InFaces[@]}"; do  # 从网口循环获取IP
    # 增加超时时间, 以免在某些网络环境下请求IPv6等待太久
    Public_IPv4=$(curl -4s --interface "$i" -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")
    Public_IPv6=$(curl -6s --interface "$i" -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")

    if [[ -n "$Public_IPv4" ]]; then  # 检查是否获取到IP地址
        IPv4="$Public_IPv4"
    fi
    if [[ -n "$Public_IPv6" ]]; then  # 检查是否获取到IP地址            
        IPv6="$Public_IPv6"
    fi
done

# 通过IP, host, 时区, 生成UUID. 重装脚本不改变, 不改变节点信息, 方便个人使用
uuidSeed=${IPv4}${IPv6}$(cat /proc/sys/kernel/hostname)$(cat /etc/timezone)
default_uuid=$(curl -sL https://www.uuidtools.com/api/generate/v3/namespace/ns:dns/name/${uuidSeed} | grep -oP '[^-]{8}-[^-]{4}-[^-]{4}-[^-]{4}-[^-]{12}')

# 如果你想使用纯随机的UUID
# default_uuid=$(cat /proc/sys/kernel/random/uuid)

# 执行脚本带参数
if [ $# -ge 1 ]; then
    # 第1个参数是搭在ipv4还是ipv6上
    case ${1} in
    4)
        netstack=4
        ip=${IPv4}
        ;;
    6)
        netstack=6
        ip=${IPv6}
        ;;
    *) # initial
        if [[ -n "$IPv4" ]]; then  # 检查是否获取到IP地址
            netstack=4
            ip=${IPv4}
        elif [[ -n "$IPv6" ]]; then  # 检查是否获取到IP地址            
            netstack=6
            ip=${IPv6}
        else
            warn "没有获取到公共IP"
        fi
        ;;
    esac

    # 第2个参数是port
    port=${2}
    if [[ -z $port ]]; then
      port=443
    fi

    # 第3个参数是域名
    domain=${3}
    if [[ -z $domain ]]; then
      domain="learn.microsoft.com"
    fi

    # 第4个参数是UUID
    uuid=${4}
    if [[ -z $uuid ]]; then
        uuid=${default_uuid}
    fi

    echo -e "${yellow} netstack = ${cyan}${netstack}${none}"
    echo -e "${yellow} 本机IP = ${cyan}${ip}${none}"
    echo -e "${yellow} 端口 (Port) = ${cyan}${port}${none}"
    echo -e "${yellow} 用户ID (User ID / UUID) = $cyan${uuid}${none}"
    echo -e "${yellow} SNI = ${cyan}$domain${none}"
    echo "----------------------------------------------------------------"
fi

echo "开始准备工作..."
apt update > /tmp/livefree.log 2>&1
echo "还是准备工作..."
apt install -y curl jq qrencode net-tools lsof >> /tmp/livefree.log 2>&1

# Xray官方脚本 安装最新版本
echo -e "${yellow}启动，Xray官方脚本安装...${none}"
bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> /tmp/livefree.log 2>&1

echo -e "${yellow}加速，更新geodata...${none}"
bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata >> /tmp/livefree.log 2>&1
echo -e "${yellow}冲刺！${none}"
# 如果脚本带参数执行的, 要在安装了xray之后再生成默认私钥公钥shortID
if [[ -n $uuid ]]; then
  #私钥种子
  private_key=$(echo -n ${uuid} | md5sum | head -c 32 | base64 -w 0 | tr '+/' '-_' | tr -d '=')

  #生成私钥公钥
  tmp_key=$(echo -n ${private_key} | xargs xray x25519 -i)
  private_key=$(echo ${tmp_key} | awk '{print $3}')
  public_key=$(echo ${tmp_key} | awk '{print $6}')

  #ShortID
  shortid=$(echo -n ${uuid} | sha1sum | head -c 16)
  
  echo -e "${yellow} 私钥 (PrivateKey) = ${cyan}${private_key}${none}" >> /tmp/livefree.log
  echo -e "${yellow} 公钥 (PublicKey) = ${cyan}${public_key}${none}" >> /tmp/livefree.log
  echo -e "${yellow} ShortId = ${cyan}${shortid}${none}" >> /tmp/livefree.log
fi

# 打开BBR
echo -e "${yellow}打开BBR${none}"
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
sysctl -p >/dev/null 2>&1

# 配置 VLESS_Reality 模式, 需要:端口, UUID, x25519公私钥, 目标网站

# 网络栈
if [[ -z $netstack ]]; then
    if [[ -n "$IPv4" ]]; then
        netstack=4
        ip=${IPv4}
    elif [[ -n "$IPv6" ]]; then
        netstack=6
        ip=${IPv6}
    else
        warn "没有获取到公共IP"
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
  echo "Random port found $port" >> /tmp/livefree.log
fi

# Xray UUID
if [[ -z $uuid ]]; then
  uuid=$default_uuid
fi

# x25519公私钥
if [[ -z $private_key ]]; then
  # 私钥种子
  private_key=$(echo -n ${uuid} | md5sum | head -c 32 | base64 -w 0 | tr '+/' '-_' | tr -d '=')

  tmp_key=$(echo -n ${private_key} | xargs xray x25519 -i)
  default_private_key=$(echo ${tmp_key} | awk '{print $3}')
  default_public_key=$(echo ${tmp_key} | awk '{print $6}')

  if [[ -z "$private_key" ]]; then 
    private_key=$default_private_key
    public_key=$default_public_key
  else
    tmp_key=$(echo -n ${private_key} | xargs xray x25519 -i)
    private_key=$(echo ${tmp_key} | awk '{print $3}')
    public_key=$(echo ${tmp_key} | awk '{print $6}')
  fi

  echo -e "${yellow} 私钥 (PrivateKey) = ${cyan}${private_key}${none}" >> /tmp/livefree.log
  echo -e "${yellow} 公钥 (PublicKey) = ${cyan}${public_key}${none}" >> /tmp/livefree.log
fi

# ShortID
if [[ -z $shortid ]]; then
  default_shortid=$(echo -n ${uuid} | sha1sum | head -c 16)
  while :; do
    #read -p "$(echo -e "(默认ShortID: ${cyan}${default_shortid}${none}):")" shortid
    [ -z "$shortid" ] && shortid=$default_shortid
    if [[ ${#shortid} -gt 16 ]]; then
      error
      continue
    elif [[ $(( ${#shortid} % 2 )) -ne 0 ]]; then
      # 字符串包含奇数个字符
      error
      continue
    else
      # 字符串包含偶数个字符
      echo -e "${yellow} ShortID = ${cyan}${shortid}${none}"
      break
    fi
  done
fi

# 目标网站
if [[ -z $domain ]]; then
  echo -e "准备 ${magenta}域名${none}"
  #read -p "(例如: learn.microsoft.com): " domain
  [ -z "$domain" ] && domain="learn.microsoft.com"
  echo -e "${yellow} SNI = ${cyan}$domain${none}"
fi

# 配置config.json
echo
echo -e "${yellow} 配置 /usr/local/etc/xray/config.json ${none}"
cat > /usr/local/etc/xray/config.json <<-EOF
{ // VLESS + Reality
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
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

# 重启 Xray
echo -e "${yellow}重启 Xray${none}"
service xray restart

# 指纹FingerPrint
fingerprint="random"

# SpiderX
spiderx=""

echo
echo -e "${yellow}搞定！${none}" 
echo -e "${yellow} 地址 (Address) = $cyan${ip}${none}"
echo -e "${yellow} 端口 (Port) = ${cyan}${port}${none}"
echo -e "${yellow} 用户ID (User ID / UUID) = $cyan${uuid}${none}"
echo -e "${yellow} 流控 (Flow) = ${cyan}xtls-rprx-vision${none}"
echo -e "${yellow} 加密 (Encryption) = ${cyan}none${none}"
echo -e "${yellow} 传输协议 (Network) = ${cyan}tcp${none}"
echo -e "${yellow} 伪装类型 (header type) = ${cyan}none${none}"
echo -e "${yellow} 底层传输安全 (TLS) = ${cyan}reality${none}"
echo -e "${yellow} SNI = ${cyan}${domain}${none}"
echo -e "${yellow} 指纹 (Fingerprint) = ${cyan}${fingerprint}${none}"
echo -e "${yellow} 公钥 (PublicKey) = ${cyan}${public_key}${none}"
echo -e "${yellow} ShortId = ${cyan}${shortid}${none}"
echo -e "${yellow} SpiderX = ${cyan}${spiderx}${none}"
if [[ $netstack == "6" ]]; then
  ip=[$ip]
fi
vless_reality_url="vless://${uuid}@${ip}:${port}?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=${domain}&fp=${fingerprint}&pbk=${public_key}&sid=${shortid}&spx=${spiderx}&#VLESS_R_${ip}"
echo "你的链接"
echo -e "${cyan}${vless_reality_url}${none}"
echo
echo "如果需要二维码，复制以下命令"
echo "qrencode -t UTF8 -r livefree.reality.txt"
echo $vless_reality_url > livefree.reality.txt
echo "以上节点信息保存在 livefree.reality.txt 中，过程中部分log在/tmp/livefree.log中"
#echo "卸载命令：bash -c \$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) @ remove --purge "
echo "---------- Live Free & Stay Strong -------------"