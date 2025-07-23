# 📦 [项目说明](README.md) | [Project](README.en.md) | [اطلاعات پروژه](README.fa.md)

> Repository: https://github.com/livingfree2023/xray-vless-reality-nokey

Many popular "one-click" scripts nowadays have become ~~bloated~~ feature-rich, ~~lost their original purpose~~ very advanced.

So I decided to package my own DIY experience into a **truly** one-click script and share it.

This modified script is even more aggressive than standard one-clicks—so what should I call it? Zero-click? Well, you do still have to press Enter… but if scripts that require 101 keystrokes still call themselves "one-click," I’ll shamelessly call mine "**NoKey**."

No domain required. Perfect for both seasoned users who love tinkering and total beginners who want a hassle-free setup.

Run a single command, sit back, and wait. No chatter, no fuss—super fast. Ready to race any other script 🚀 Speed is my specialty.

> In testing, even a modest 1vCPU/1GB RAM VPS completed setup in under 20 seconds. Ideal for busy users.

---

# ⚙️ Features (without passing any parameters, it goes from a fresh machine to installing BBR + FQ)

1. Skips unnecessary `apt` updates automatically  
2. Skips redundant `geodata` updates  
3. Generates UUID/KeyPair using official commands  
4. Auto-detects a random free port  
5. Adapts across multiple Linux distributions  
6. Uses official Xray-core installer  
7. Accepts parameters for protocol stack, UUID, SNI, port  
8. Shows help with `--help`  
9. Outputs only minimal steps—detailed logs saved to a file  
10. Generates QR codes  
11. More features coming soon...

---

# 🧑‍🍳 How to Use (as root)

```bash
bash -c "$(curl -sL https://raw.githubusercontent.com/livingfree2023/xray-vless-reality-nokey/refs/heads/main/nokey.sh)"
```

---

# 🧹 Uninstalling Xray-core (this script leaves no trace, so uninstalling isn’t really necessary)

```bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```

---

# ⭐ Please give it a star :)

Mistakes are inevitable—feedback is welcome!

_Forked from https://github.com/crazypeace/ — thanks to the original author._

---

If you’d like, I can help you write a localized README that switches between this translation and the original using links or folders. Just say the word!
