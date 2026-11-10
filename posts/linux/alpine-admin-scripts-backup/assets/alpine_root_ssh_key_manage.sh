#!/bin/ash

# 强制定义路径
HOME="/root"

# 颜色定义
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_hong='\033[31m'
gl_bai='\033[0m'
gl_hui='\e[37m'

# 检查权限与依赖
init_check() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${gl_huang}提示: ${gl_bai}该功能需要 root 用户才能运行！"
        exit 1
    fi
    # 自动安装 Alpine 缺失的常用工具
    if ! command -v curl >/dev/null 2>&1 || ! command -v nano >/dev/null 2>&1; then
        apk add --no-cache curl nano openssh-keygen openssh-client >/dev/null 2>&1
    fi
}

# 获取 IP 地址
ip_address() {
    ipv4_address=$(curl -s --connect-timeout 5 https://ipinfo.io/ip)
    [ -z "$ipv4_address" ] && ipv4_address="VPS_IP"
}

# 重启 SSH 服务
restart_ssh() {
    rc-service sshd restart >/dev/null 2>&1
}

# 开启密钥模式 (核心逻辑：查缺补漏，防止重复)
sshkey_on() {
    local conf="/etc/ssh/sshd_config"
    local backup="${conf}.bak"
    local filtered new_config
    local channel_timeout=""
    [ -f "$backup" ] || cp -p "$conf" "$backup" || return 1
    if sshd -T -o ChannelTimeout=session=10m >/dev/null 2>&1; then
        channel_timeout="ChannelTimeout session=10m"
    else
        echo -e "${gl_huang}提示: 当前 OpenSSH 不支持 ChannelTimeout；ClientAlive 仅会断开失联客户端，不会退出仍在线的空闲 shell。${gl_bai}" >&2
    fi
    filtered=$(mktemp "${conf}.XXXXXX") || return 1
    new_config=$(mktemp "${conf}.XXXXXX") || { rm -f "$filtered"; return 1; }

    if ! awk 'function upper(value) { return toupper(value) }
        upper($1) ~ /^(PERMITROOTLOGIN|PASSWORDAUTHENTICATION|PUBKEYAUTHENTICATION|CHALLENGERESPONSEAUTHENTICATION|KBDINTERACTIVEAUTHENTICATION|USEPAM|ALLOWTCPFORWARDING|ALLOWAGENTFORWARDING|X11FORWARDING|CLIENTALIVEINTERVAL|CLIENTALIVECOUNTMAX|CHANNELTIMEOUT)$/ { next }
        { print }' "$conf" > "$filtered"; then
        rm -f "$filtered" "$new_config"
        return 1
    fi

    {
        cat <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM no
AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    } > "$new_config" || { rm -f "$filtered" "$new_config"; return 1; }
    [ -z "$channel_timeout" ] || printf '%s\n' "$channel_timeout" >> "$new_config"
    cat "$filtered" >> "$new_config" || { rm -f "$filtered" "$new_config"; return 1; }
    chmod 600 "$new_config"
    chown root:root "$new_config"
    mv -f "$new_config" "$conf" || { rm -f "$filtered"; return 1; }
    rm -f "$filtered"

    if ! sshd -t -f "$conf"; then
        cp -p "$backup" "$conf"
        echo -e "${gl_hong}sshd 配置校验失败，已恢复备份。${gl_bai}" >&2
        return 1
    fi
    
    restart_ssh
    echo -e "${gl_lv}已启用密钥登录并关闭密码、键盘交互及 SSH 转发；支持时，session 空闲 10 分钟后断开。${gl_bai}"
    sleep 2
}

# 确保目录权限正确
ensure_ssh_dir() {
    [ ! -d "$HOME/.ssh" ] && mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    [ ! -f "$HOME/.ssh/authorized_keys" ] && touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
}

# 1. 生成新密钥对
add_sshkey() {
    ensure_ssh_dir
    local key_path="$HOME/.ssh/sshkey"
    
    ssh-keygen -t ed25519 -C "admin@vps" -f "$key_path" -N ""
    cat "${key_path}.pub" >> "$HOME/.ssh/authorized_keys"
    
    ip_address
    echo -e "\n${gl_lv}密钥对生成成功！${gl_bai}"
    echo -e "请保存私钥，建议文件名: ${gl_huang}${ipv4_address}_ssh.key${gl_bai}"
    echo "------------------------------------------------"
    cat "$key_path"
    echo "------------------------------------------------"
    sshkey_on
}

# 2. 手动导入公钥
import_sshkey() {
    ensure_ssh_dir
    printf "${gl_hui}请粘贴公钥内容: ${gl_bai}"
    read pub_content
    if [ -z "$pub_content" ]; then
        echo -e "${gl_hong}错误：输入内容为空${gl_bai}"; return 1
    fi
    echo "$pub_content" >> "$HOME/.ssh/authorized_keys"
    sshkey_on
}

# 3. 从 GitHub 导入
import_github() {
    ensure_ssh_dir
    printf "${gl_hui}请输入 GitHub 用户名: ${gl_bai}"
    read username
    if [ -n "$username" ]; then
        curl -fsSL "https://github.com/${username}.keys" >> "$HOME/.ssh/authorized_keys"
        echo -e "${gl_lv}GitHub 公钥导入尝试完成${gl_bai}"
        sshkey_on
    fi
}

# 主菜单
sshkey_panel() {
    init_check
    while true; do
        clear
        REAL_STATUS=$(grep -i "^PubkeyAuthentication" /etc/ssh/sshd_config | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
        IS_KEY_ENABLED="${gl_hui}未启用${gl_bai}"
        [ "$REAL_STATUS" = "yes" ] && IS_KEY_ENABLED="${gl_lv}已启用${gl_bai}"
        
        echo -e "Alpine SSH 密钥管理面板 ${IS_KEY_ENABLED}"
        echo "------------------------------------------------"
        echo "1. 生成新密钥对 (ED25519)"
        echo "2. 手动输入已有公钥"
        echo "3. 从 GitHub 导入公钥"
        echo "4. 编辑公钥文件 (authorized_keys)"
        echo "5. 查看当前密钥信息"
        echo "0. 退出"
        echo "------------------------------------------------"
        printf "请输入选择: "
        read choice
        case $choice in
            1) add_sshkey ;;
            2) import_sshkey ;;
            3) import_github ;;
            4) nano "$HOME/.ssh/authorized_keys" ;;
            5)
                echo -e "\n${gl_huang}--- 已授权公钥 ---${gl_bai}"
                [ -s "$HOME/.ssh/authorized_keys" ] && cat "$HOME/.ssh/authorized_keys" || echo "为空"
                echo -e "\n${gl_huang}--- 本地私钥 (如有) ---${gl_bai}"
                [ -f "$HOME/.ssh/sshkey" ] && cat "$HOME/.ssh/sshkey" || echo "未找到"
                printf "\n按回车继续..."; read dummy ;;
            0) exit 0 ;;
            *) echo "无效选择"; sleep 1 ;;
        esac
    done
}

sshkey_panel
