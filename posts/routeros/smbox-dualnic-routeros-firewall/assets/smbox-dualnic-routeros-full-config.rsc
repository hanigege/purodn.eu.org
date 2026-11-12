# 双网口 RouterOS 7 完整恢复配置
# 配置目标：ether1=LAN / bridge1，ether2=WAN DHCP
# LAN IPv4=10.0.0.1/24，sing-box 网关=10.0.0.6 / fd88:1::6
# 不含用户名密码或 ISP PPPoE 凭据；先确认物理网口顺序。
# 本脚本面向新设备；filter 与 srcnat 清理命令会替换对应配置。

# 0. 设备标识、时区和 NTP
/system identity
set name="DualNIC-RouterOS"
/system clock
set time-zone-autodetect=no time-zone-name=Asia/Shanghai
/system ntp client
set enabled=yes mode=unicast servers=ntp1.aliyun.com,time1.cloud.tencent.com,cn.pool.ntp.org,time.windows.com

# 1. 网口、LAN Bridge、接口列表
/interface ethernet
set [find where default-name=ether1] name=lan comment="LAN 内网物理口"
set [find where default-name=ether2] name=wan comment="WAN 上联物理口"
/interface bridge
add name=bridge1 protocol-mode=rstp comment="LAN 内网 Bridge"
/interface bridge port
add bridge=bridge1 interface=lan comment="LAN 口加入 bridge1"
/interface list
add name=LAN comment="可信内网接口列表"
add name=WAN comment="动态上联接口列表"
/interface list member
add list=LAN interface=bridge1 comment="LAN bridge 加入 LAN 列表"
add list=WAN interface=wan comment="WAN 接口加入 WAN 列表"

# 2. LAN IPv4、DHCP、DNS
/ip address
add address=10.0.0.1/24 interface=bridge1 comment="LAN IPv4 网关"
/ip pool
add name=dhcpv4-pool1 ranges=10.0.0.100-10.0.0.250 comment="LAN DHCP 地址池"
/ip dhcp-server
add name=dhcpv4-server1 interface=bridge1 address-pool=dhcpv4-pool1 lease-time=1d disabled=no comment="LAN DHCP Server"
/ip dhcp-server network
add address=10.0.0.0/24 gateway=10.0.0.1 dns-server=10.0.0.1 comment="LAN DHCP 网段"
/ip dns
set servers=10.0.0.6 allow-remote-requests=yes cache-size=8192KiB

# 3. WAN 动态 IPv4、LAN ULA、WAN IPv6 RA
/ip dhcp-client
add interface=wan add-default-route=yes default-route-distance=1 use-peer-dns=no use-peer-ntp=no disabled=no comment="WAN 动态 IPv4"
# ISP 使用 PPPoE 时，在 WinBox 建立 PPPoE Client 并输入账号密码后，执行以下两项
# /interface list member
# add list=WAN interface=pppoe-out1 comment="PPPoE 动态 WAN"
# /ip dhcp-client
# disable [find where interface=wan]
/ipv6 address
add address=fd88:1::1/64 interface=bridge1 advertise=yes comment="LAN IPv6 ULA"
/ipv6 nd
add interface=bridge1 ra-interval=5m-15m advertise-mac-address=no advertise-dns=no comment="LAN IPv6 RA"
/ipv6 settings
set forward=yes accept-router-advertisements=yes accept-router-advertisements-on=WAN

# ISP 支持 DHCPv6-PD 时可选启用；WAN IPv6 默认路由仍由 RA 获取
# 若启用 PD，IPv6 防火墙已在 WAN 放行 DHCPv6 客户端响应；无需对委派的全局前缀做 NAT66
# /ipv6 dhcp-client
# add interface=wan request=prefix pool-name=wan-ipv6-pool add-default-route=no use-peer-dns=no disabled=no comment="ISP 动态 IPv6 Prefix Delegation"
# /ipv6 address
# add address=::1/64 from-pool=wan-ipv6-pool interface=bridge1 advertise=yes comment="LAN 使用 ISP 委派的动态前缀"

# 需要动态域名时可选启用；DDNS 不会自动开放端口，也不能穿透 CGNAT
# /ip cloud
# set ddns-enabled=yes update-time=yes

# 4. sing-box 双栈路由表和默认网关
/routing table
add name=sing-box-v4 fib
add name=sing-box-v6 fib
/ip route
add dst-address=0.0.0.0/0 gateway=10.0.0.6 routing-table=sing-box-v4 distance=1 comment="sing-box IPv4 默认路由"
/ipv6 route
add dst-address=::/0 gateway=fd88:1::6 routing-table=sing-box-v6 distance=1 comment="sing-box IPv6 默认路由"

# 5. IPv4 代理目的地址列表（当前配置共 42 条）
/ip firewall address-list
add list=proxy_ipv4 address=28.0.0.0/8 comment="IPv4 FakeIP"
add list=proxy_ipv4 address=1.1.1.1 comment="IPv4 DNS 目的地址"
add list=proxy_ipv4 address=1.0.0.1 comment="IPv4 DNS 目的地址"
add list=proxy_ipv4 address=8.8.8.8 comment="IPv4 DNS 目的地址"
add list=proxy_ipv4 address=8.8.4.4 comment="IPv4 DNS 目的地址"
add list=proxy_ipv4 address=8.41.4.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=23.23.189.144/28 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=23.246.0.0/18 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=34.195.253.0/25 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=37.77.184.0/21 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=38.72.126.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=45.57.0.0/17 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=52.24.178.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=52.35.140.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=54.204.25.0/28 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=54.213.167.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=64.120.128.0/17 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=66.197.128.0/17 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=69.53.224.0/19 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=103.87.204.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=108.175.32.0/20 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=185.2.220.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=185.9.188.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=192.173.64.0/18 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=198.38.96.0/19 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=198.45.48.0/20 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=203.75.84.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=203.198.13.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=203.198.80.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=207.45.72.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=208.75.76.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=210.0.153.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=91.108.56.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=91.108.4.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=91.108.8.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=91.108.16.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=91.108.12.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=149.154.160.0/20 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=91.105.192.0/23 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=91.108.20.0/22 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=185.76.151.0/24 comment="IPv4 代理服务网段"
add list=proxy_ipv4 address=95.161.64.0/20 comment="IPv4 代理服务网段"

# 6. IPv6 代理目的地址列表（当前配置共 6 条）
/ipv6 firewall address-list
add list=proxy_ipv6 address=2001:2::/64 comment="IPv6 FakeIP"
add list=proxy_ipv6 address=2001:b28:f23d::/48 comment="IPv6 代理服务网段"
add list=proxy_ipv6 address=2001:b28:f23f::/48 comment="IPv6 代理服务网段"
add list=proxy_ipv6 address=2001:67c:4e8::/48 comment="IPv6 代理服务网段"
add list=proxy_ipv6 address=2001:b28:f23c::/48 comment="IPv6 代理服务网段"
add list=proxy_ipv6 address=2a0a:f280::/32 comment="IPv6 代理服务网段"

# ROS-AB 分阶段规则需要的三个禁用列表占位项
/ip firewall address-list
add list=ros_ab_stage1 address=0.0.0.0/32 disabled=yes comment="ROS-AB 禁用占位项"
add list=ros_ab_stage2 address=0.0.0.0/32 disabled=yes comment="ROS-AB 禁用占位项"
add list=ros_ab_stage3 address=0.0.0.0/32 disabled=yes comment="ROS-AB 禁用占位项"

# 7. 策略路由和 MSS clamp
/ip firewall mangle
add chain=prerouting action=mark-routing new-routing-mark=sing-box-v4 passthrough=yes dst-address-list=proxy_ipv4 comment="IPv4 代理目的地址策略路由"
add chain=forward action=change-mss new-mss=clamp-to-pmtu passthrough=yes tcp-flags=syn protocol=tcp comment="IPv4 转发 TCP MSS clamp"
add chain=output action=change-mss new-mss=clamp-to-pmtu passthrough=yes tcp-flags=syn protocol=tcp comment="IPv4 本机 TCP MSS clamp"
/ipv6 firewall mangle
add chain=prerouting action=mark-routing new-routing-mark=sing-box-v6 passthrough=yes dst-address-list=proxy_ipv6 comment="IPv6 代理目的地址策略路由"
add chain=forward action=change-mss new-mss=clamp-to-pmtu passthrough=yes tcp-flags=syn protocol=tcp comment="IPv6 转发 TCP MSS clamp"
add chain=output action=change-mss new-mss=clamp-to-pmtu passthrough=yes tcp-flags=syn protocol=tcp comment="IPv6 本机 TCP MSS clamp"
/routing rule
add routing-mark=sing-box-v6 action=lookup-only-in-table table=sing-box-v6 comment="IPv6 sing-box 策略表查询"

# 8. 管理服务、MAC Server、邻居发现和 UPnP
# LAN 配置完成后再限制 opsadmin 的来源地址；首次 MAC 登录不要提前限制
# /user set [find where name=opsadmin] address=10.0.0.0/24
# 确认 opsadmin 可登录后再禁用默认 admin
# /user disable [find where name=admin]
/ip service
set [find where name=ssh] port=2222 address=10.0.0.0/24
set [find where name=winbox] port=5391 address=10.0.0.0/24
disable [find where name=ftp]
disable [find where name=telnet]
disable [find where name=www]
disable [find where name=www-ssl]
disable [find where name=api]
disable [find where name=api-ssl]
set [find where name=reverse-proxy] address=10.0.0.0/24
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
/ip neighbor discovery-settings
set discover-interface-list=LAN
/ip upnp
set enabled=no

# 9. IPv4 filter：替换所有现有 filter；确认不需保留自定义规则
# IPv4 Filter 共 19 条（input 11 条 + forward 8 条）
/ip firewall filter
remove [find]
add chain=input action=accept connection-state=established,related,untracked comment="IPv4 入站：允许已建立、相关、未跟踪连接"
add chain=input action=drop connection-state=invalid comment="IPv4 入站：丢弃无效连接"
add chain=input action=accept in-interface-list=LAN comment="IPv4 入站：允许 LAN 访问路由器"
# ROS-AB 共 5 条，仅监控 WAN 入站 TCP 新连接 2222、5391，不开放端口
add chain=input action=drop connection-state=new protocol=tcp src-address-list=bruteforce_blacklist in-interface-list=WAN dst-port=2222,5391 comment="ROS-AB 1：丢弃黑名单源"
add chain=input action=add-src-to-address-list connection-state=new protocol=tcp src-address-list=ros_ab_stage3 address-list=bruteforce_blacklist address-list-timeout=3d in-interface-list=WAN dst-port=2222,5391 comment="ROS-AB 2：第三级加入三天黑名单"
add chain=input action=add-src-to-address-list connection-state=new protocol=tcp src-address-list=ros_ab_stage2 address-list=ros_ab_stage3 address-list-timeout=1h in-interface-list=WAN dst-port=2222,5391 comment="ROS-AB 3：第二级升第三级"
add chain=input action=add-src-to-address-list connection-state=new protocol=tcp src-address-list=ros_ab_stage1 address-list=ros_ab_stage2 address-list-timeout=15m in-interface-list=WAN dst-port=2222,5391 comment="ROS-AB 4：第一级升第二级"
add chain=input action=add-src-to-address-list connection-state=new protocol=tcp address-list=ros_ab_stage1 address-list-timeout=5m in-interface-list=WAN dst-port=2222,5391 comment="ROS-AB 5：首次连接记入第一级"
add chain=input action=accept protocol=icmp in-interface-list=WAN comment="IPv4 入站：允许 WAN ICMP"
add chain=input action=drop in-interface-list=WAN comment="IPv4 入站：丢弃 WAN 其他访问"
add chain=input action=drop comment="IPv4 入站：丢弃其余所有访问"
# sing-box 已建立连接保护需位于通用 established 规则之前
add chain=forward action=accept connection-state=established,related,untracked src-address=10.0.0.6 comment="IPv4 转发：sing-box 发出流量跳过 FastTrack"
add chain=forward action=accept connection-state=established,related,untracked dst-address=10.0.0.6 comment="IPv4 转发：发往 sing-box 的流量跳过 FastTrack"
add chain=forward action=accept connection-state=established,related,untracked comment="IPv4 转发：允许已建立、相关、未跟踪连接"
add chain=forward action=accept connection-state=invalid dst-address=28.0.0.0/8 in-interface=bridge1 out-interface=bridge1 comment="IPv4 转发：例外放行 LAN 到 LAN FakeIP"
add chain=forward action=drop connection-state=invalid comment="IPv4 转发：丢弃无效连接"
add chain=forward action=accept in-interface-list=LAN comment="IPv4 转发：允许 LAN 出站"
add chain=forward action=accept connection-nat-state=dstnat in-interface-list=WAN comment="IPv4 转发：允许 WAN 的 DSTNAT"
add chain=forward action=drop comment="IPv4 转发：丢弃其余所有流量"

# 10. IPv6 filter
# IPv6 Filter 共 14 条（input 6 条 + forward 8 条）
/ipv6 firewall filter
remove [find]
add chain=input action=accept connection-state=established,related,untracked comment="IPv6 入站：允许已建立、相关、未跟踪连接"
add chain=input action=drop connection-state=invalid comment="IPv6 入站：丢弃无效连接"
add chain=input action=accept protocol=icmpv6 comment="IPv6 入站：允许 ICMPv6 RA、邻居发现和 PMTUD"
add chain=input action=accept in-interface-list=LAN comment="IPv6 入站：允许 LAN 访问路由器"
add chain=input action=accept protocol=udp src-address=fe80::/10 in-interface-list=WAN dst-port=546 comment="IPv6 入站：允许 WAN 上游 DHCPv6-PD 响应"
add chain=input action=drop comment="IPv6 入站：丢弃其余所有访问"
add chain=forward action=accept connection-state=established,related,untracked src-address=fd88:1::6 comment="IPv6 转发：sing-box 发出流量跳过 FastTrack"
add chain=forward action=accept connection-state=established,related,untracked dst-address=fd88:1::6 comment="IPv6 转发：发往 sing-box 的流量跳过 FastTrack"
add chain=forward action=accept connection-state=established,related,untracked comment="IPv6 转发：允许已建立、相关、未跟踪连接"
add chain=forward action=accept connection-state=invalid dst-address=2001:2::/64 in-interface=bridge1 out-interface=bridge1 comment="IPv6 转发：例外放行 LAN 到 LAN FakeIP"
add chain=forward action=drop connection-state=invalid comment="IPv6 转发：丢弃无效连接"
add chain=forward action=accept protocol=icmpv6 comment="IPv6 转发：允许 ICMPv6 控制报文"
add chain=forward action=accept in-interface-list=LAN comment="IPv6 转发：允许 LAN 出站"
add chain=forward action=drop comment="IPv6 转发：丢弃其余所有流量"

# 11. 限定 IPv4 NAT 和 IPv6 NAT66
/ip firewall nat
remove [find where chain=srcnat]
add chain=srcnat action=masquerade src-address=10.0.0.0/24 out-interface-list=WAN comment="IPv4 NAT：仅伪装 LAN 出 WAN"
/ipv6 firewall nat
remove [find where chain=srcnat]
add chain=srcnat action=masquerade src-address=fd88:1::/64 out-interface-list=WAN comment="IPv6 NAT66：仅伪装 ULA 出 WAN"

# FastTrack 保持关闭。

