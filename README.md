# antiS
**一款中文、粤语、藏语、维语友好，隐私加强的操作系统（基于 Slackware Live，GNU/Linux 发行版）**

> 曾用名：LiveSlak，现改为 antiS：anti-Surveillance —— 对抗监控、审查，捍卫自己的网络自由。  


主要集成功能：  
  - 中文化(约80%) 粤语（80%） 藏语（50%） 维语（60%）
  - 隐私加强
    - 隐私保护类和信息/通讯自由相关的应用
	- live 性质，重启后系统恢复初始状态（不保存任何修改，不留下任何痕跡）
    - 系统加固（包括：防火墙、文件系统挂载限制、内核参数配置等……）
	- 沙盒（firejail）
	- 强制访问控制（AppArmor）（目前为可选）

最后更新：2020.01.29  

發佈頻道/群组：	
- Telegram: 
	- https://t.me/liveslak    
	- https://t.me/liveslackware      


## Download

- 下载地址 
	- https://sourceforge.net/projects/liveslak-atgfw/files/iso/
	- Version: **2020.01.0**    
	- md5sum: a0b849f751aaccb2e9c4429b5651e7e0

- Main Updates (as of this version):
	- Massive packages updating (including Kernel 5.4.14); 
	- Fix locale to UTC so as to start obfs4proxy in Tor; many others.
	- More anti-forensics: do not mount every partitions in local HDD; hide local partitions in File Manager.
**注：过往记录见：[Changelog](https://github.com/mdrights/LiveSlak/blob/mdrights/Changelog)**
<hr>

## Usage

- 了解本发行版的具体特性，请阅读：    
	- [基本介绍](https://mdrights.github.io/os-observe/Liveslak-intro/)  
	- [使用手册](https://github.com/mdrights/LiveSlak/blob/V1.3.0/skel/Desktop/LiveSlak-Users-Guide.md)  
	- [预装软件列表](https://github.com/mdrights/LiveSlak/blob/V1.3.0/pkglists/mdrights-xfce.lst)  
	- 溫馨提示：本系統雖然有一定匿名特性，但不主打匿名，請有高匿名需求的朋友使用：[Tails](https://tails.boum.org/about/index.en.html)  

## Installation

- 将 iso 文件装入USB盘：   
0. 插入 USB 盤後，找出你的 U 盤是什麼編號：   
	- 在 Linux：   
	```
		$ lsblk  
		 (如果你的系統自動掛載了，需要卸載它——圖形界面的直接點「彈出」即可)
	```  
	- 在 macOS：  
	```
		$ diskutil list   (查看)    
		$ diskutil unmountDisk /dev/diskX   (系統會默認掛載，我們卸載它)
	```  

1. 方法1：（在 Linux 和 macOS）用 `dd` 命令；
	```
	sudo dd bs=4M if=/path/to/antis-xxxx.xx.iso of=/dev/XXX    (注意請看清你的 USB 盤是什麼編號喲)
	```
2. 方法2：使用本 repo 内的 `iso2usb.sh` 脚本安装（暫時只能在大部分 Linux 發行版運行）：
	1. 這種方法讓系统安装到 USB 盘后所有更改都是永久的；
	2. 可以选择加密用户家目录。例子（-o: USB盘，-c: 加密 home 目录的大小；-w: 启动时等待USB盘挂载的时间）：
	```
	bash iso2usb.sh -i /home/antis-xxxx.xx.iso -o /dev/sdb -c 25G -w 10
	```

- 在插入電腦開機時設置 BIOS，讓 USB 盤優先引導。
	- 不同電腦 BIOS 不同，怎麼進入 BIOS 可參考下表：
	
	| Manufacturer | Key                |
	|--------------|--------------------|
	| Acer         | Esc, F12, F9       |
	| Asus         | Esc, F8            |
	| Clevo        | F7                 |
	| Dell         | F12                |
	| Fujitsu      | F12, Esc           |
	| HP           | F9, Esc            |
	| Lenovo       | F12, Novo, F8, F10 |
	| Samsung      | Esc, F12, F2       |
	| Sony         | F11, Esc, F10      |
	| Toshiba      | F12                |
	| others…      | F12, Esc           |

- 找到`Boot Order` 這樣的選項，讓類似 `USB` 或你的 U 盤品牌的名字排到最前。


## Device Requirements

- 您的机器必须是 `x86_64` 位的 **PC** 啦 (macOS 不太支持) ；
- 需要至少 2G 内存；
- 这意味着如果你在虚拟机里运行，请为其设置足够的内存，而虚拟机的宿主机至少要有 4G 物理内存。
- 经测试，有的电脑只有 (U)EFI（主板启动固件）, Slackware 的 bootloader (syslinux + grub2) 可能无法广泛地支持所有 UEFI。如果遇到机器无法识别本系统的U盘——这情况请选择传统 BIOS 或带 CSM 的 EFI的电脑使用，或者在虚拟机里使用（并请告诉我 Orz）。



## Build

**如果你也想自己制作 LiveSlak 系统**   

1. 你需要先下载 Slackware 的官方源（内有构建 Slackware 所有的包）：https://mirrors.slackware.com  

2. 如果你需要用自己定制的内核，可以把重新编译好的内核包和内核模块包覆盖进上述下载的官方内核和模块包即可。通常官方内核和模块包在：`<your/path>/slackware64-current/slackware64/a`   记得 Liveslak 只采用 generic 内核包，因此你的定制内核包的名称要和官方源里的 generic 内核包相同。

3. 如果你有第三方软件需要加进 Liveslak，可以参考下面的打包脚本先制作 Slackware 安装包，然后把制作的包（tgz 或 txz）放置于一个目录下（比如 $HOME/liveslak），LiveSlak 构建时会导入这些软件包：

    - Liveslak 采用：[Slackbuilds-nonprism](https://github.com/mdrights/Slackbuilds-nonprism) 
    - 还有这里： [Slackwarecn-slackbuilds](https://github.com/slackwarecn-slackbuilds)
	- 还有 Slackbuilds（半官方脚本源）：[slackbuilds.org](https://slackbuilds.org)

    为了达到这个目的，请自行创建（或修改）本repo里的 xxx.conf & xxx.lst 配置文件（也可以用我的：mdrights{.conf, .lst}）   
    其中 `SL_REPO` 变量要指向放置你的软件包的目录。

4. 其他修改/自定义的地方就是：`make_slackware_live.conf`   
        - `SL_REPO` = 你的本地 Slackware （官方）仓库地址  
        - `LIVEDE`  = 给它起个名字吧  

5. 运行构建脚本(如我的)：
	`./make_slackware_live.sh -R 3 -l zh_cn -v`  


## Acknowledgement

> Forked from Alien Bob's powerful building script for Slackware Live. Credits to Alien !    
> 本套脚本 forked 自 [Alien Bob](http://www.slackware.com/%7Ealien/liveslak/), git://bear.alienbase.nl/liveslak.git
- 非常感謝 Aaron Nexus @Telegram 給予的測試;-) 

<hr>
构建脚本的详细介绍和使用方法请见 Alien的 [README.txt](https://github.com/mdrights/LiveSlak/blob/mdrights/README.txt)   

**交流反饋**：這裏發issue，或 IRC: #DigitalrightsCN (Freenode); 或 Matrix：antis:matrix.org ; 或 Telegram:  https://t.me/liveslackware   

**([姊妹 live 隱私增強操作系統：antiG](https://github.com/mdrights/antiG))**

<hr>
<br />

> Copyright 2014 - 2017 Eric Hameleers, Eindhoven, NL 
> Copyright 2017 - 2019 MDrights (mdrights at tutanota dot de)  
> All rights reserved  

> 只要本版权声明和许可声明出现在所有版本的本软件中， 本软件即可被允许以任何目的（有偿或无偿地）使用、复制、修改和分发。  

>
   Permission to use, copy, modify, and distribute this software for
   any purpose with or without fee is hereby granted, provided that
   the above copyright notice and this permission notice appear in all
   copies.
>
   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
   SUCH DAMAGE.


