# RouterOS 7 新装示例。先按文章核对 bridge1、10.0.0.0/24、10.0.0.1、10.0.0.2、dc00::2222。
# 仅导入一次；已有同名路由表、路由或 NAT 规则时，按文章的迁移步骤修改原规则。
# sing-box 的 FakeIP 地址池须先设置为 198.18.0.0/15 和 2001:2::198:18:0:0/96。

/routing table add fib name=sing-box-v4
/routing table add fib name=sing-box-v6
/ip route add dst-address=0.0.0.0/0 gateway=10.0.0.2 routing-table=sing-box-v4 comment="SB FakeIP example v4 gateway"
/ipv6 route add dst-address=::/0 gateway=dc00::2222 routing-table=sing-box-v6 comment="SB FakeIP example v6 gateway"
/routing rule add action=lookup dst-address=198.18.0.0/15 table=sing-box-v4 comment="SB FakeIPv4 198.18/15"
/routing rule add action=lookup dst-address=2001:2::198:18:0:0/96 table=sing-box-v6 comment="SB FakeIPv6 /96"
/routing rule add action=lookup dst-address=1.1.1.1/32 table=sing-box-v4 comment="SB DNS 1.1.1.1"
/routing rule add action=lookup dst-address=1.0.0.1/32 table=sing-box-v4 comment="SB DNS 1.0.0.1"
/routing rule add action=lookup dst-address=8.8.8.8/32 table=sing-box-v4 comment="SB DNS 8.8.8.8"
/routing rule add action=lookup dst-address=8.8.4.4/32 table=sing-box-v4 comment="SB DNS 8.8.4.4"

# 必须排在现有的 Drop invalid forward 前，防止 FakeIP TCP 握手被丢弃。
/ip firewall filter add chain=forward action=accept connection-state=invalid dst-address=198.18.0.0/15 in-interface=bridge1 out-interface=bridge1 place-before=0 comment="SB allow invalid LAN FakeIPv4"
/ipv6 firewall filter add chain=forward action=accept connection-state=invalid dst-address=2001:2::198:18:0:0/96 in-interface=bridge1 out-interface=bridge1 place-before=0 comment="SB allow invalid LAN FakeIPv6"

# 仅将客户端访问这四个 IPv4 DNS 的 TCP/53 接管给 sing-box，排除 sing-box 自身。
/ip firewall address-list add list=sb-public-dns-tcp address=1.1.1.1 comment="SB DNS TCP resolver"
/ip firewall address-list add list=sb-public-dns-tcp address=1.0.0.1 comment="SB DNS TCP resolver"
/ip firewall address-list add list=sb-public-dns-tcp address=8.8.8.8 comment="SB DNS TCP resolver"
/ip firewall address-list add list=sb-public-dns-tcp address=8.8.4.4 comment="SB DNS TCP resolver"
/ip firewall address-list add list=sb-dns-upstream-excluded address=10.0.0.2 comment="SB DNS upstream exclusion"
/ip firewall nat add chain=srcnat action=src-nat to-addresses=10.0.0.1 protocol=tcp src-address=10.0.0.0/24 dst-address=10.0.0.2 src-address-list=!sb-dns-upstream-excluded in-interface=bridge1 out-interface=bridge1 dst-port=53 place-before=0 comment="SB DNS TCP hairpin src"
/ip firewall nat add chain=dstnat action=dst-nat to-addresses=10.0.0.2 to-ports=53 protocol=tcp src-address=10.0.0.0/24 dst-address-list=sb-public-dns-tcp src-address-list=!sb-dns-upstream-excluded in-interface=bridge1 dst-port=53 place-before=0 comment="SB DNS TCP hairpin dst"
