# LiveSlak
构建我自己的 Live 发行版 （基于 Slackware）。


> Forked from Alien Bob's powerful building script for Slackware Live. Credits to Alien !    
> 本套脚本 forked 自 [Alien Bob 大牛](http://www.slackware.com/%7Ealien/liveslak/), git://bear.alienbase.nl/liveslak.git



2018.04 主要集成功能：  
  - 中文化(约80%)
  - 隐私加强
    - 隐私保护类和信息/通讯自由相关的应用
    - 系统加固（包括：防火墙、文件系统挂载限制、内核参数配置等……）
	- 沙盒（firejail）
	- 基于角色的访问控制（AppArmor）(TODO)

最后更新：2018.10.21     

發佈頻道：		https://t.me/liveslak    


## Download

- 下载地址 
	- https://sourceforge.net/projects/liveslak-atgfw/files/iso/
	- Version: 2018.04.rc3
	- md5sum: 7041ed3f5781ff1773908363ffcea1e7  


<hr>

## Usage

- 了解本发行版的具体特性，请阅读：    
	- [LiveSlak 最终用户介绍](https://mdrights.github.io/os-observe/Liveslak-intro/)
	- [《LiveSlak 用户手册》](https://github.com/mdrights/LiveSlak/blob/mdrights/LiveSlak-Users-Guide.md)
	- [预装软件列表](https://github.com/mdrights/LiveSlak/blob/V1.3.0/pkglists/mdrights-xfce.lst)


## Device Requirements

- 您的机器必须是 `x86_64` 位的啦；
- 需要至少 2G 内存；
- 这意味着如果你在虚拟机里运行，请为其设置足够的内存，而虚拟机的宿主机至少要有 4G 物理内存。
- 经测试，有的电脑只有 (U)EFI（主板启动固件）, Slackware 的 bootloader (syslinux + grub2) 可能无法广泛地支持所有 UEFI。如果遇到机器无法识别本系统的U盘——这情况请选择传统 BIOS 或带 CSM 的 EFI的电脑使用，或者在虚拟机里使用（并请告诉我 Orz）。

**注：具体更新记录和我的更改见：[Changelog](https://github.com/mdrights/LiveSlak/blob/mdrights/Changelog)**

## Build

**如果你也想自己制作 LiveSlak 系统**   

可以参考这里的打包脚本制作Slackware安装包（打包方法见每个脚本里的README）：

- [Slackbuilds-nonprism](https://github.com/mdrights/Slackbuilds-nonprism) 

- 还有更多： [Slackwarecn-slackbuilds](https://github.com/slackwarecn-slackbuilds)

把用以上打包脚本构建的包（tgz 或 txz）放置于同一个目录下（比如 $HOME/slackwareCN），LiveSlak 构建时会导入这些软件包。

    为了达到这个目的，请自行创建（或修改）本repo里的 xxx.conf & xxx.lst 配置文件（也可以用我的：mdrights{.conf, .lst}）   
    其中 `SL_REPO` 变量要指向放置你的软件包的目录（比如 $HOME/slackwareCN）

其他修改/自定义的地方就是：`make_slackware_live.conf` 
  - `SL_REPO` = 你的本地 Slackware （官方）仓库地址
  - `LIVEDE`  = 给它起个名字吧


## Acknowledgement

- 非常感謝 TG上的 Aaron Nexus 給予的測試;-)  Thanks a million for Aaron Nexus (on Telegram) for tireless testing :)

<hr>
构建脚本的详细介绍和使用方法请见 Alien的 [README.txt](https://github.com/mdrights/LiveSlak/blob/mdrights/README.txt)   

**交流反饋**：這裏發issue，或 IRC/Matrix: #DigitalrightsCN; TG頻道：https://t.me/liveslak ; 或 群组:  https://t.me/liveslackware   

**([姊妹 live 隱私增強操作系統：antiG](https://github.com/mdrights/antiG))**


==============================================================================   
Copyright 2014 - 2017 Eric Hameleers, Eindhoven, NL  
Copyright 2017 - 2018 MDrights (mdrights at tutanota dot de)  
All rights reserved  

只要本版权声明和许可声明出现在所有版本的本软件中，本软件即可被允许以任何目的（有偿或无偿地）使用、复制、修改和分发。  

    Permission to use, copy, modify, and distribute this software for
#   any purpose with or without fee is hereby granted, provided that
#   the above copyright notice and this permission notice appear in all
#   copies.
#
#   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.
# -----------------------------------------------------------------------------

