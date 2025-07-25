# 📦 [项目说明](README.md) | [Project](README.en.md) | [اطلاعات پروژه](README.fa.md)

> 项目地址: https://github.com/livingfree2023/xray-vless-reality-nokey
> 
> 如果你只是想换个端口，换个uuid，或者买的新鸡急着去测youtube/speedtest，这个脚本可能非常适合你

![image](https://img.imgdd.com/ce4a1b42-9219-4957-95df-1a67a844b162.png)

各大有名的一键脚本现在~~越来越臃肿，早就忘记了初心~~功能非常强大，选择非常多样

自己把自己的手搓经验撮成一个真的一键脚本，分享一下

这个魔改的一键脚本，比一键更激进，那我该叫什么？零键？其实还是要按回车键的，但是那些要按101个键的脚本都还叫一键脚本，我只好tiǎn着脸叫“零键”(NOKEY)了

不需要域名，既适合会手搓的超级用户，也适合无需过多信息的纯小白，没有花里胡哨，快是我的强项，干就完了

一个命令下去就等结果就好了，不罗嗦，不打扰，速度超快，敢和任何脚本PK ^-^ 输了告诉我，我再改进

默认不带参数直接从新机器开始到装完BBR+FQ，魔改功能为
1. 自动跳过不必要的系统环境更新
2. 自动跳过不必要的geodata更新（--force参数可强制更新）
3. 按照官方命令生成UUID/KeyPair
4. 自动找随机空闲端口（10000以上，--port可指定任意）
5. 尽可能自动适配所有linux版本
6. xray-core直接用原装正版脚本安装
7. 可带参数指定协议栈，UUID，SNI，端口
8. 可查看帮助 --help
9. 只输出极简步骤，详细log输出到log文件
10. 支持X25519，为此安装最新的pre-release了，但是官方脚本没有给alpine参数去下prerelease，会玩的请自行折腾
11. 暂时想到这么多……

> 已测试包括：ubuntu22/debian11/Rocky9.2/CentOS7.6/Fedora30/Alma9.2/alpine3.22，欢迎测试提issue或者报告成功结果

# 食用方式

在root下执行
```
bash -c "$(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-nokey/refs/heads/main/nokey.sh)"
```
如果没有ipv4（纯v6的鸡），同时如果warp了ipv4的出口，此时要指定入口为v6，否则连不通（因为v4优先级比v6高）
```
bash -c "$(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-nokey/refs/heads/main/nokey.sh)" @ --netstack=6
```
强制更新xray 和 geodata
```
bash -c "$(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-nokey/refs/heads/main/nokey.sh)" @ --force
```

错误难免，请多指教，我希望能做出适合所有linux版本的，但是自己财力有限，欢迎大佬借我机器调试


# 卸载xray-core 
> XTLS官方脚本，非Alpine
```
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```
> Alpine
```
rc-service xray stop
rc-update del xray    
rm -rf "/usr/local/bin/xray"  
rm -rf "/usr/local/share/xray" 
rm -rf "/usr/local/etc/xray/"  
rm -rf "/var/log/xray/" 
rm -rf "/etc/init.d/xray" 
```


_感谢 [crazypeace](https://github.com/crazypeace/)_
_感谢 [@RPRX](https://github.com/RPRX)_
_感谢 [ProjectX](https://github.com/XTLS)_
