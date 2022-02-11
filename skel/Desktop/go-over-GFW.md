# 科学上网指南

> antiS 配备了常用的翻墙工具，有些是没有图形界面的只能在命令行启动（此乃 Linux 也）。
因此这些命令如下：（点开「终端模拟器」，输入（可复制粘贴）相应的命令，注意把< > 之间的信息替换为你自己的）  

- v2rayA: 图形化界面，直接在程序菜单启动即可  
    - （每次开机进入系统后它需要下载一些程序需花费些时间；由于它是由Docker启动，需要输入用户的密码；具体使用方法请阅读它的官方文档：https://v2raya.org）  
    - **注**：它是在浏览器里运行，如果在菜单里的点击没有带出浏览器，请手动在浏览器里访问：http://localhost:2017 ）

- Outline:   
    - 方法一：需先在终端启动它的一个进程，然后在程序菜单启动即可：
```
    sudo /etc/rc.d/rc.outline-proxy-controller start
```
    - 方法二：在终端执行启动脚本：
```
    start-outline-client.sh
```

- shadowsocks-libev:
```
  ss-local -c <你的配置文件的路径>
```

- go-shadowsocks2:
```
  go-shadowsocks2 -c 'ss://AEAD_CHACHA20_POLY1305:<密码>@<服务器IP>:<服务器端口>' \
    -verbose -socks :1080 -u -udptun :8053=8.8.8.8:53,:8054=8.8.4.4:53 \
                             -tcptun :8053=8.8.8.8:53,:8054=8.8.4.4:53
```

- v2ray-core:
```
  v2ray run -c <你的配置文件的路径>
```

- Openconnect (Cisco VPN 的开源客户端)
	(使用方法请阅读 `man openconnect`)
```
	openconnect <your vpn server>
```

- Wireguard (新型轻量高安全性 VPN)  
```
    （先把配置文件如 wg0.conf 放到 /etc/wireguard/ (如没有就创建一个)）

    sudo wg-quick up wg0
```
