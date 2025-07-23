# 说明 
> 项目地址: https://github.com/livingfree2023/xray-vless-reality-livefree/_

各大有名的一键脚本现在越来越臃肿，又大又全，早就忘记了初心，变的不伦不类，各种提示新手看不懂，老手看的累，

自己把自己的手搓经验撮成一个真的一键脚本，分享一下，

这个魔改的一键脚本，比一键更激进，那我该叫什么？0键？其实还是要按回车键的，但是那些要按101个键的脚本都还叫一键脚本，我只好tiǎn着脸叫“零键脚本”了

不需要域名，适合会手搓的超级用户，或者纯小白

一个命令下去就等结果就好了，不罗嗦，不打扰，速度超快，敢和任何脚本PK ^-^ 输了告诉我，我再改进

默认不带参数直接从新机器开始到装完BBR，魔改功能为
1. 自动跳过不必要的apt更新
2. 自动跳不必要的geodata更新
3. 按照官方命令生成UUID/KeyPair
4. 自动找随机空闲端口
5. 多linux版本自动适配
6. xray-core直接用原装正版脚本
7. 可带参数指定协议栈，UUID，SNI，端口
8. 可看帮助 --help
9. 只输出极简步骤，详细log输出到log文件
10. 可生成二维码
11. 暂时想到这么多……

食用方式：在root下执行

```
bash -c  "$(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-livefree/refs/heads/main/0key.sh)"
```


# 卸载xray-core （本脚本无影无形无需卸载）
```
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```

# 用你的STAR告诉我你有用过 STAR! :)


_Fork于 https://github.com/crazypeace/  感谢原作_
