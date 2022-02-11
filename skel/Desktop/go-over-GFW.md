# 科学上网指南

> antiS 配备了常用的翻墙工具，有些是没有图形界面的只能在命令行启动（此乃 Linux 也）。
因此这些命令如下：（点开「终端模拟器」，输入（可复制粘贴）相应的命令，注意把< > 之间的信息替换为你自己的）  

- v2rayA: 
```
  start-v2rayA.sh
```
    - （每次开机进入系统后它需要下载一些程序需花费些时间；由于它是由Docker启动，需要输入用户的密码；具体使用方法请阅读它的官方文档：https://v2raya.org）  
    - **注**：它是在浏览器里运行，如果在菜单里的点击没有带出浏览器，请手动在浏览器里访问：http://localhost:2017 

- Outline:   
```
    start-outline-client.sh
```
    - （由于它需要有一个进程持续在后台运行，启动时需要输入用户的密码。然后按提示输入你的 Outline 服务器 key 即可。成功连接后即可全局翻墙；具体使用方法见：https://getoutline.org ）  

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
    - （该命令启动后会在本地监听 1080 端口，其他应用设置 socks5 代理即可；其全局代理命令见其官方 Github README ）  

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
