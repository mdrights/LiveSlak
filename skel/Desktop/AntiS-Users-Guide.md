---
layout: post
date: 2020-11-15
---

# LiveSlak 用户手册   

**默认帐号/密码：live/live**    
**默认root密码：toor**     


### LiveSlak 能防御什么 & 不能防御什么

**请一定阅读这一部分**   

- 能防御什么  
> 从邮件附件、外界进入的文档/图片中的恶意程序，网页下载下来的木马，如果无法阻挡，那就防止它们**长期**驻留在系统对用户进行监视并回传用户数据，并保持一个干净的操作系统；   
> 不会对本地（原来）的系统和磁盘内容有任何影响，可以当作一个隔离的环境（如不联网的话）；
> 另一方面，也可以作为一个安全的查看不安全的、不信任的文件/程序的平台。

- 不能防御什么   
> 1. 木马等恶意程序下载到当前环境； 
> 2. 如果当前环境有木马下载下来，并且当前环境中有敏感文件，并不能防止木马读取这些文件（除非使用一些隔离技术如沙盒（firejail））；   

### 【再强调一次：使用策略】    

1. 当前系统不要保留重要敏感文件（反正也不會保存），文件需要保存的话请转存到其他盘上；
2. **注意区分使用场景**：  
	- 总体有两类场景：
		- 1. 打开、运行不信任的文件/软件；  
		- 2. 打开、运行信任的但是私密的、安全需求高的文件/软件；  
	- 当我们每次开机进入 live 系统时，都要想一想我是要把这个系统用于哪类场景。因为 live 系统都是隔离的环境，我的目的是想防止文件/软件里潜在的恶意程序的破坏呢？还是为了不让高度敏感的文件被泄漏？  
	
> 也就是说，如果你这次开机选择的是第一个场景，就请尽量不要把放了重要文件的 U 盤挂载到当前环境，如果你这次环境选择的是第二个场景，那不联网是最好的。  

3. （在虚拟机里使用时）下载下来的文件就不要再在宿主环境里打开了（就是安装了 Virtualbox 的那个系统））


## 启动方法  

1.  USB 盤插入电脑，启动电脑；
	- 如果你的电脑还没设置 USB 设备优先启动，请先设置（方法请自行搜索）；  
	- 开机画面是个大大的「Slackware」，在开机画面可以选择：
	    - 不同的语言（目前有英语、简体中文、台湾正体、香港繁体、藏文、维吾尔文和日文）
		- 不同的时区（推荐`UTC` 这样隐匿性更好）  
2. 修改用户和/或root的密码（只对本次启动有效）   
在系统开机画面（显示蓝色的`Slackware`及一些菜单）时，按大写`E`进入一个编辑页面，在`linux`那行紧随句尾输入以下参数:
```
	livepw="xxxx"
	和/或
	rootpw="xxxx"
```
按 F10 保存并启动系统。  
3. 出现`login:` 表示可以登录了，输入`live`然后回车；输入密码时是不回显任何东西的——Linux 特色;-)  
4. 登录系统后，是命令行界面，**需要执行**`startx`进入桌面。


## 软件使用方法

### 關於文件權限

- 对几款常用软件（chromium, firefox, signal-desktop, Telegram, thunderbird, Zoom）都将**默认**由 firejail 启动，在沙盒中运行（已在程序菜单设置好）。  
> 這就意味著：這些軟件只能讀取和創建/修改 live 用戶的 `Desktop`和`下載` 目錄下的文件了。 部分軟件也不允許使用輸入法。  

- 实验性加入 QQ —— 这个流氓间谍软件 —— 但相信在本系统上其流氓行为可得到限制。在程序菜单将由 firejail 启动。   
> 這就意味著：它看不見 live 用戶的**家目錄**（`/home/live`）下的所有文件和目錄。要上傳文件請把文件放到`/tmp`，也只能把文件下載到那裡。  

- 对默认用户的账号（live）的家目录进行权限梳理，  
    - `live` 用户自己创建的文件将是 `rw-r-----`，目录将是 `rwxr-x---`。這意味著：  
> 非 `live` 用户不能查看、添加、修改、删除 `live` 家目录（`/home/live`）下的文件/目录了。  

### 基本需求
- fcitx 輸入法     
	（按 `Ctrl + 空格` 激活；目前有拼音/双拼/五笔/注音等）

- NetworkManager
	网络连接工具，如果你是用 USB 盤啓動本系統，請点击右上角图标连接WiFi（如果点出的菜单没有见到任何热点，很可能是本系统没有该机器无线网卡的驱动）；用虛擬機方式則不必特意设置。    
	（另，已MAC地址随机化处理可更好保護你的網上身份） 

- Firefox 火狐浏览器   
	- 现在已经套用了安全沙盒（firejail）并默认配置了经过安全/隐私加固的配置，包括： Socks 代理（很多翻墙软件需要这个设置才能让浏览器翻墙）、不加载第三方 cookie 并关闭 Firefox 时清除 cookie、防指纹跟踪（fingerprint），以及其他配置。这些配置可能会让某些网页显示有问题。用户可以随时改回默认的配置（只对本次开机有效）。  

- Chromium 浏览器（Chrome 的开源版）   
    - 注：需要走代理时只能从命令行启动（在程序菜单已默认如此，并默认使用安全沙盒 firejail 启动）：  
    ```  
        chromium --proxy-server="socks5://localhost:1080"   (例子：你的本地 1080 端口的 ss / v2ray 代理)   
    ```     

- 如何挂载本地硬盘或外置存储（如U盘/移动硬盘等）    
	- 自2020年版本开始默认设置了不能直接在文件管理器左侧就能看到你机器本地的磁盘（分区）了（为了对非技术人员做适当隐藏）。但仍然可以通过命令行挂载。  
	- 外接的U盘、移动硬盘一般都能识别。磁盘挂载时会弹出提示要求密码，请输入 root（超级管理员）的密码：`toor`    



### 穿墙
- Shadowsocks-libev  
	（方法一：把 ss 配置文件放在桌面，**文件名必须**是：`config.json`，然后点击「应用程序」菜单——「翻越长城」——「Shadowsocks-libev」即可（**注意**点击后不会有任何显示，只有一个黑窗口弹出要求输入 root 密码）   
	
	（方法二：在终端，进入 ss 配置文件的路径，执行：   
```   
	ss-local -c <你的 ss 配置文件>

	> 比如，你的 ss 配置文件在桌面的话：  

	ss-local -c ~/Desktop/config.json  
```   
	
- ss-redir 透明代理，可以让本地的和同一内网（包括手机）的应用走代理。（**试验**）  
	（把 ss 配置文件放在桌面，**文件名必须**是：`config.json`）
	  然后在应用程序菜单的「翻越长城」点击`shadowsocks-libev 透明代理`；
	  它随后会启动 ss-redir 和防火墙。它会打开一个终端窗口，要求输入用户的密码，输入完后会告知启动成功与否，5秒后会关闭窗口但不影响程序运行。）   

- v2ray  
	（启动方法：在终端执行：）  
```
	v2ray -c <你的 v2ray 配置文件>  
```

- Protonmail Bridge (Protonmail Bridge 客户端后台 -- 从应用程序菜单进入)

- ProtonVPN CLI (ProtonVPN 命令行客户端，具体用法参见它的帮助信息)
```
	protonvpn examples
```

- Openconnect (- Cisco VPN 的开源客户端)
	(使用方法请阅读 `man openconnect`)
```
	openconnect <your vpn server>
```

- Wireguard (新型轻量高安全性 VPN)  
```
    （先把 配置文件如 wg0.conf 放到 /etc/wireguard/ (如没有就创建一个)）

    sudo wg-quick up wg0
```


### 隐匿/隐身
- Tor Browser 洋葱浏览器 ( & Tor 命令行版 )    
	（如果选择用自己的代理，第一個問題選否，第二個選是，在Socks5處選擇 127.0.0.1 端口 1080 ）   
	（也可以使用自备的网桥）    
- Tor 高级模式 （暂未包括）    
- iceWM 
    （可以模仿 Win95 的桌面主题，让你在公共场所不被周围的人发现你在用 Linux 系统，更好地物理隐匿。）
```
    在开机登录（login）后，输入 startx 时改为：

    startx /usr/bin/icewm

    进入桌面后在开始菜单选择 「themes」即可选择 Win95 主题。
```
 

### 安全地聯繫 
- Telegram 
	(可在設置裏設置 socks（1080）代理（翻牆），或 Tor（9050））
    （已默认由安全沙盒 firejail 启动）  

- Hexchat, Weechat    
	( IRC 客戶端，無需註冊帳戶；記得本軟件最好要 **走代理（包括翻牆或Tor）再用** ！！！否則會直接暴露你的 IP 地址）

- Pidgin
	（XMPP 协议的客户端；可以在设置里设置代理）

- Riot.im --> 已改名：Element  
	（新型“邦联化”(基于Matrix) 聊天/协作工具(可加密)，可以完美桥接 IRC，slack 等平台）   
	（为了简化，本地应用已舍去，可以使用 web 网页版：https://app.element.io ）  

- uTox   
	（p2p架构的（去中心化）通讯工具）   

- MatterMost
	（类似 Slack 的开源替代）

- Signal-Desktop 桌面版
	（加密通讯软件；须先在移动设备安装Signal客户端并用帐号登录；注意它自身无法设置代理。）
    （已默认由安全沙盒 firejail 启动）  

- 邮件客户端：Thunderbird 和 mutt （均可配合 GPG 使用加密邮件）
    （Thunderbird 已默认由安全沙盒 firejail 启动）  

- 另外临时附带 `Zoom` 和 `QQ`，**不开源**的通讯工具，警告：仅为使用方便，请自行评估其安全性。
    （已默认由安全沙盒 firejail 启动）  


### 文件分享
- onionshare
	（通过 Tor 网络分享文件）
- Syncthing
	（分布式地分享文件）


### 加密大法   
- Keepassxc
	（密码管理器）  	
- VeraCrypt     
	（加密工具） 
- GnuPG     
	(当然啦，GPG 是每款 GNU/Linux 都自带哒）
- gpa   
	(PGP密钥管理器)


### 数据清除 vs 反数据清除   
- wipe, secure-delete     
	（磁盘擦除工具 -注：一般仅对 **传统磁盘** 有效）   
	（在終端，`wipe` 接你要刪除的文件/目錄 即可；   
	secure-delete 則包括：    
	`srm`: 反覆擦除文件/目錄    
	`sfill`: 填充磁盤或某個目錄的可用空間（一般耗時很長.avi）   
	`smem`: 擦除內存中的數據（不知要等到什麼時候.jpg）
- testdisk    
	（数据恢复工具，在終端裏輸入 `testdisk` 即可按提示操作）

### Metadata  
- Exiftool
- MAT2

### Malware Analysis  
- peepdf  
- pdftool  
- pdf-parser.py  
- pdfid.py  
- oledump  
- oletools  


### 一些高級用法  
- 防火牆 iptables    
	（在桌面菜单「网络」里，會要求輸入用戶密碼 `live`；配有一些簡單的規則。默认已经开启）
- firejail    
	（沙盒，用于隔离应用软件，執行 `firejail` 後接你想要運行的程序即可）
- macchanger
	（MAC地址随机化工具）
- proxychains    
	（网络代理工具；用於在終端中讓程序走代理，已設成 本地的 1080 端口）
- privoxy    
	（网络代理工具, http 代理服務器；用於讓本地和同網的其他機器的流量走代理（像全局一樣）~（還需進一步設置））
- dnscrypt-proxy  
	(使用 DoH / DNSSEC 方法的 DNS 请求客户端，让你的 DNS 请求更加隐蔽，不被本地网管/ISP 记录。不使用 代理/VPN 时可用。)  
	使用方法：在终端执行  
```
	/etc/rc.d/rc.dnscrypt-proxy start

	然后修改你的 DNS 解析 IP：

    vi /etc/resolv.conf

	把所有 nameserver 删去，改为：

	nameserver 127.0.0.1
```
	

### 其他日常：
- Libreoffice （文檔編輯套件）  
- Retext (Markdown 文字编辑器） 
- docx2txt  （docx格式转换 txt）  
- Audacious (音频编辑）
- GIMP （图像编辑）
- Mplayer （视频播放）
- xsane （扫描）  
- 注：看PDF 文件可使用 Firefox 或 Libreoffice。




