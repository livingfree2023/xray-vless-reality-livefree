# 📦 [项目说明](README.md) | [Project](README.en.md) | [اطلاعات پروژه](README.fa.md)
> 项目地址: https://github.com/livingfree2023/xray-vless-reality-nokey

各大有名的一键脚本大现在越来越~~臃肿~~功能完善，~~早就忘记了初心~~非常高级

自己把自己的手搓经验撮成一个真的一键脚本，分享一下

这个魔改的一键脚本，比一键更激进，那我该叫什么？0键？其实还是要按回车键的，但是那些要按101个键的脚本都还叫一键脚本，我只好tiǎn着脸叫“零键”(NOKEY)了

不需要域名，既适合会手搓的超级用户，也适合无需过多信息的纯小白，用户体验是我最看重的。

一个命令下去就等结果就好了，不罗嗦，不打扰，速度超快，敢和任何脚本PK ^-^ 输了告诉我，我再改进

默认不带参数直接从新机器开始到装完BBR+FQ，魔改功能为
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
bash -c  "$(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-nokey/refs/heads/main/nokey.sh)"
```


# 卸载xray-core （本脚本无影无形无需卸载）
```
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```

# 用你的STAR告诉我你有用过 STAR! :)

错误难免，请多指教

_Fork于 https://github.com/crazypeace/  感谢原作_
