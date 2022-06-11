#!/bin/sh -eux

# 修改文件句柄数
echo '*   -   nofile    65535 ' >>/etc/security/limits.conf

echo "*               soft    nofile           1000000
*               hard    nofile          1000000">>/etc/security/limits.conf
echo "ulimit -SHn 1000000">>/etc/profile

# ubuntu 没有 selinux 默认使用的是apparmor，可用 sudo /etc/init.d/apparmor stop 关闭

# 防火墙
ufw enable
ufw allow 22
ufw allow 51888
ufw reload

# 修改登录时的欢迎信息
chmod -x /etc/update-motd.d/*        # 取消默认的 motd 
info="Welcome! Do Not Use rm -rf ,Have a Nice Day!"

if [ -d /etc/update-motd.d ]; then
    MOTD_CONFIG='/etc/update-motd.d/99-info'

    cat >> "$MOTD_CONFIG" <<info
#!/bin/sh

cat <<'EOF'
$info
EOF
info

    chmod 0755 "$MOTD_CONFIG"
else
    echo "$info" >> /etc/motd
fi

echo "系统正在重启，请勿关闭此窗口...."
reboot
