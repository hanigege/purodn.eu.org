# RouterOS 7 新装示例。先按文章核对 bridge1、10.0.0.0/24、10.0.0.1、10.0.0.2、dc00::2222。
# 仅导入一次；已有同名路由表或路由规则时，按文章的迁移步骤修改原规则。
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
