
## Change Log

- 2021.02.04 (`2021.01.01`)  
    - Signal-desktop 已经可以直接使用～；  
    - 安全更新：sudo, firefox, etc.  
    - 对默认用户的账号（live）的家目录进行权限梳理，非 `live` 用户不能添加、修改、删除 `live` 家目录（`/home/live`）下的文件/目录了 (但能看到文件/目录名)。  
    - `live` 用户自己创建的文件将是 `rw-r-----`，目录将是 `rwxr-x---`。  
    - 去掉一些闭源的系统工具（系统自带的）。  

- 2021.01.03 (`2021.01`)  
    - Added: Wireguard, Chromium, tools for Yubikey :).

- 2020.11.15 (`2020.03.02`)  
	- Added: protonmail-bridge, protonvpn-cli; ship Signal-desktop as uninstalled package.
- 2020.10.25 (`2020.03.01`)  
	- Rebuilt: Signal-desktop  
- 2020.10.06 (`2020.03`)  
	- Added: openconnect (an open source alternative to CISCO's VPN client); Updated: Signal-desktop.  
	- Routine updates. New: Internet Radio, Wireguard (not working yet).  

- 2020.06.14 (`2020.02.01`)  
	- A hardened Firefox configuration (user.js forked from [here](https://github.com/ghacksuserjs/ghacks-user.js)) has been added, thus: proxy over port 1080, clear-on-close cookies, anti-fingerprinting and more configs become the default.  
	- Dnscrypt-proxy is added, used for better DNS privacy when user is not using proxy/VPN.  

- 2020.05.17 (`2020.02`)  
	- Massive packages updating; added Outline, V2ray, Terminator; noto-font removed.  
	- Add `iceWM` which can enable a desktop micmicking Win95 style, thus better anonymity.  

- 2020.01.29 (`2020.01`)
	- Massive packages updating (including Kernel 5.4.14); many others:
	Keepassxc and obfs4 added; IPFS, FreeRDP removed; AppArmor and WireGuard are still not added; 
	- Fix locale to UTC so as to start obfs4proxy in Tor; 
	- More anti-forensics: do not mount every partitions in local HDD; hide local partitions in File Manager.
	- use zsh for user `live`.

- 2019.09.08 (`2019.03`正式版发布！)
	- 修复 ssl certificate 缺失的问题；
	- 增加了几个应用的 desktop 文件，方便套用`firejail`启动这些应用（位于程序菜单里的「翻越长城」里）；
	- 更新 Tor，Tor-browser，Telegram，Signal-Desktop等。

- 2019.06.16 (`2019.02`正式版发布！)
1. 新增 twitter (Twitter 的命令行客户端)
2. 补充了 newsboat 的依赖：stfl

- 2019.06.07
1. 改名：antiS，anti-surveillance
2. 新增一些软件，移除不用的软件（如果您有特别想用的软件，可以发 issue 告诉我）。
3. 美化了桌面和终端的字体。

- 2019.05.03
1. 内核、基础包、SBo源的包等更新；
2. 新增：Onionshare，MatterMost, Docker,Freerdp, Noto- fonts-CJK | Slack, Zoom（注：这两款为非开源软件，由于比较流行才暂时收入）
3. 移除：Jitsi（官方不再维护），Brave Browser（暂时移出以缩小体积）
4. 增强：Firefox 添加了 user.js 开启后默认设置了cookie相关选项和自动进入隐私模式。

- 2019.01.02
1. 官方源和 SBo 源 和自己打包的软件进行了更新；
2. 重新编译的内核 4.19.13（开启了 AppArmor）；
2. 新增 Brave 隐私增强型浏览器；ReText：一个 Markdown 编辑器。

- 2018.10.06	
1. 把主脚本升级到 1.3.0（可支持制作时制定默认locale了；同时增加可以手动指定内核版本）；
2. 去掉了多余的locale；
3. 新增 WireGuard(VPN)、；
4. ~~新增 AppArmor，并使用自己编译 4.9.131
内核（为了开启关于AppArmor的选项）；~~  
5. 换了壁纸，代号：老大哥。  
- 2018.09.24	大更新：1) 实现了 ss-redir 的透明代理功能！2) 内核 4.14.70；Tor浏览器-> 8.0 (Tor
		0.3.4.8)，Shadowsocks-libev -> 3.2.0, Riot.im -> 0.16.3, Telegram
1.3.14, uTox 0.17.0, 弃 Keepassx 改 Keepassxc，Signal-Desktop 1.16.0,
	libreoffice 6.1.1, etc.
- 2018.02.19	大更新：内核 4.9.81（CPU两漏洞补丁上游已完善）；Tor浏览器-> 7.5，Shadowsocks-libev -> 3.1.3, v2ray -> 3.9, Riot.im -> 0.13.5, Telegram 1.2.6, etc.; 抛弃cinnamon，拥抱xfce，用了自定义的 pkglist -> xfce 安装了完整的 slackware官方包了；重整了xfce菜单，重要软件的菜单项添加中文，并归到独自的子菜单：「翻越长城」和「数据保护」； 自制的 ATGFW 桌面（声援甄江华并支持他和伙伴的网站）
- 2018.01.14	use my self-built kernel: 4.9.76 which was directly from kernel.org as the patched and updated version in response to Meltdown and Spectre. Updated Tor (0.3.2.9) 
- 2017.12.08	新增：Shadowsocks（原版，2.9.1）；更新：v2ray（3.0.1），Tor（0.3.2.6-alpha）；系统官方更新（内核 4.9.66）  
- 2017.11.10	更新 Tor (3.2.3-alpha), Tor Browser(7.0.9), Icecat(52.3.0), Icecat-hardened（安装后即可用插件了：Noscript, HTTPSeverywhere, Privacy Badger，和中文语言包）; XFCE版去除了 GIMP（减轻重量），CINNAMON版增加了 youtube-dl（油管下载神器）；官方更新跟进（eg -> Firefox 56).  
- 2017.10.28	跟进官方10.20更新（包括wpa_supplicant安全更新）；新增 Riot 客户端，qTox 客户端（p2p分布式通讯应用）；	
- 2017.10.07	暂时**移除**蓝灯（因为发现其在用阿里云的海外服务器，可信度大大降低）；新增 `v2ray`；修复ssr/ss-libev脚本的bugs。  
- 2017.10.04	新增了 Tor-messenger 和 Lantern蓝灯（注：蓝灯并非在所有地区都有效）。
- 2017.10.03	加入了藏文（bo_IN, bo_CN）和维吾尔文（ug_CN）的显示支持（注：目前来说维吾尔文支持较好，而有些应用/桌面没有藏文的翻译项目，还需要更多藏语使用者对各应用和桌面（如 XFCE）提供翻译。）  
- 2017.09.30	更新一些自添加的软件：Tor-nonprism（修复防火墙规则）；Icecat-hardened（用户配置改为无痕浏览和默认socks5代理（不过启动两次浏览器才生效））；升级 shadowsocks-libev至3.1.0；新增 Signal-Desktop；Libreoffice 新增中文包，即界面默认为中文了；新增ssr脚本和 ss-redir透明代理脚本（详情见《用户手册》）。
- 2017.09.24	上游更新（包括添加了 python 3.6）
- 2017.09.17	上游系統更新（見[repo](https://mirrors.slackware.com/slackware/slackware64-current/ChangeLog.txt)）；包括內核升至4.9.50，修復包括BlueBorne藍牙模塊的漏洞。
- 2017.09.16	增加了 Jitsi；修正 Tor-hardened的錯誤（去掉 chroot功能；保留了 Tor 的 Stream Isolation 配置（可用）；增加了 iptables防火牆規則，可以讓**本地**所有DNS流量強制走 Tor，避免了DNS泄漏（透明代理）；還增加了 iptables規則可讓本系統變身 “洋蔥” 網關，連接並流入本系統的機器的所有流量都走Tor隧道（透明代理））。
- 2017.09.09	增加了一些与数据保护相关的工具： `wipe`, `secure-delete`, `testdisk`; 增加了文本编辑器：`Ted`, `docx2txt`。
- 2017.09.07	去掉了一些不必要的配置文件；修正桌面快捷方式的错误并添加了一个；在XFCE版作为超级轻量版舍去一些因缺少依赖而无法运行的包（可待在MATE版提供）。
- 2017.09.06	添加了两个桌面快捷方式：防火墙和无线网络连接。
- 2017.09.05	Discard firewall startup script; All things work now!
- 2017.09.04	First beta point release: firewall startup added to rc.local/rc.local_shutdown (but found conflicted with xdm)
- 2017.09.03	First beta release:	Tor user account added; Firewall rc script added; ShadowsockR added in /opt.
- 2017.08.27	First beta pre-release: basic feature done (but Tor un-functionable)


## My modification

- 519: Change the default locale in the first option on the syslinux boot menu, to zh; and delete the option/submenus for non-US keyboard.
- 1366 & 1896: chmod a bunch of rc files as to disable them starting in booting: e.g. bluetooth,rpc,cups. If NetworkManager is installed, disabling inet1 and wireless as well.
- 2248: Enabling the addons/ & optional/ directories under XFCE mode (substituted by SLACKWARE)
- 167+: Remove some serials of Slackware repo in the tagfiles strings of MATE and CINNAMON.
- 1295: Add user account for Tor.
- 1591: Disable most of the KDE4 configuration (for X system) when not building for KDE4 type.
- Custom_config: Add my configuration files to the system, which can be put under such paradigm:    
  - skel/skel\*.txz : any files except skel-xfce.txz in it will be put to $HOME under **every desktopType except XFCE** which only parse skel-xfce.txz;
  - rootcopy/ : now we can have **etc-x.txz** & **opt-x.txz** that can be parsed to /etc and /opt respectively. (otherwise seems rootcopy/ doesn't work)  
- ....: Add Chinese (simp, trad, Cantonese) encodings options on the bootup screen.
- Add my own pkglist: mdrights{.conf,.lst} 
    - 增加了的包绝大多数为自己编译，列表在：https://github.com/mdrights/LiveSlak/blob/mdrights/pkglists/mdrights.lst
    - 您有何提议可以发issue告诉我喔～
    - 如果希望在线获得这些软件包，我可以考虑在线共享（但仍建议你自己编译）。
- Hard-coded $KVER in line 2101, in order to let my sel-built kernel work. Also, my self-built kernel packages replaced with the same-name ones in `Slackware-repo` in my machine. The result seems to show that the kernel-generic was the one it used in place (I replaced both generic and huge packages with the same kernel built based on huge-4.9.66). I didn't build kernel-headers. And it was only successful that the kernel-modules package installed while the modules were installed via the kernel-[generic|huge] packages already. So I made kernel-modules package as a meta-package (empty but only a text in /lib/modules ). There's no need to touch tagfiles and pkglist/min.lst.   

## TODO

- Firefox and Icecat user config files (user.js, extensions.ini) are not able to install to user's directory, since the FF/Icecat user `.mozilla` directory has not been made until FF/icecat first start; and the profile directory inside `.mozilla` is a random number. However this does not affect FF's extension installation (but icecat will).
- It seems xdm cannot start DE while Iptables autostart during the boot.
- It seems that the UEFI grub won't show menu when it is initiated, with only the `boot:` prompt. Nothing has been found to figure this out yet (neither not the problem of grub fonts, nor the problem of the minimal installation under XFCE...)
