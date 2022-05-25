#!/bin/sh -eux


# -----------------------   action 函数开始（shell脚本执行成功时输出带有颜色的 OK 否则输出带有颜色的 FAILED） -----------------------
BOOTUP=color
RES_COL=60
MOVE_TO_COL="echo -en \\033[${RES_COL}G"
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_WARNING="echo -en \\033[1;33m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
LOGLEVEL=1

echo_success() {
    [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
    echo -n "["
    [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
    echo -n $"  OK  "
    [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
    echo -n "]"
    echo -ne "\r"
    return 0
}

echo_failure() {
    [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
    echo -n "["
    [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
    echo -n $"FAILED"
    [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
    echo -n "]"
    echo -ne "\r"
    return 1
}

# Run some action. Log its output.
action() {
    local STRING rc

    STRING=$1
    echo -n "$STRING "
    shift
    "$@" && echo_success $"$STRING" || echo_failure $"$STRING"
    rc=$?
    echo
    return $rc
}

# ----------------------------------------------   action 函数开始结束 ----------------------------------------------


# 更改 yum 源
yumConfig(){
  mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

  if command -v wget >/dev/null 2>&1; then
    wget --no-check-certificate -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
  elif command -v curl >/dev/null 2>&1; then
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
  else
    echo "Cannot download yum repo config";
    exit 1;
  fi

  sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
  yum makecache

  echo ""
}


# 安装软件
installSoftware(){
  rpm --import http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
  yum -y update
  # Delta RPMs disabled because /usr/bin/applydeltarpm not installed 报错，用 yum -y install deltarpm
  yum -y install wget curl gcc unzip vim-enhanced lsof net-tools bash-completion
  echo ""
}


# 这个函数的以前是再 ks.cfg 中
rename_eth0(){
  # 修改网卡名为 eth0（以下的操作重启后生效，所以将其放在此处）
  GRUB_CONFIG="/etc/default/grub"
  GRUB_CMDLINE_LINUX='GRUB_CMDLINE_LINUX="crashkernel=auto net.ifnames=0 biosdevname=0"'
  if grep -q -E "GRUB_CMDLINE_LINUX" "$GRUB_CONFIG"
  then
    sed -i "s/^\s*GRUB_CMDLINE_LINUX.*/${GRUB_CMDLINE_LINUX}/" "$GRUB_CONFIG"
  else
    echo "$GRUB_CMDLINE_LINUX" >>"$GRUB_CONFIG"
  fi

  # 设置 grub 等待时间为 1s
  GRUB_TIMEOUT="GRUB_TIMEOUT=1"
  if grep -q -E "GRUB_TIMEOUT" "$GRUB_CONFIG"
  then
    sed -i -e 's/^GRUB_TIMEOUT=[0-9]\+$/GRUB_TIMEOUT=1/' "$GRUB_CONFIG"
  else
    echo "$GRUB_TIMEOUT" >>"$GRUB_CONFIG"
  fi

  grub2-mkconfig -o /boot/grub2/grub.cfg

  # 修改网卡文件名以及设备名
  for ifcfg in `ls /etc/sysconfig/network-scripts/ifcfg-* |grep -v ifcfg-lo`
  do
    #mv $ifcfg /etc/sysconfig/network-scripts/ifcfg-eth0
    sed -i -e 's/^\s*NAME.*/NAME=eth0/' /etc/sysconfig/network-scripts/ifcfg-eth0
    sed -i -e 's/^\s*DEVICE.*/DEVICE=eth0/' /etc/sysconfig/network-scripts/ifcfg-eth0
  done

  echo ""
}


# 清除多余的系统虚拟账号
delUser(){
  chattr -i /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/inittab
  for user in `cat /etc/passwd |grep -vE "root|daemon|shutdown|halt|echoxu|dbus|polkitd|chrony|sshd|mail|bin" |awk -F':' '{print $1}'`
  do  
    userdel -r $user &>/dev/null && echo "成功删除 $user" || echo "删除 $user 失败"
  done
}


# 设置 echoxu 账号无密码且拥有 sudo 权限
userNOPASSWD(){
  echo 'Defaults:echoxu !requiretty' > /etc/sudoers.d/echoxu
  echo '%echoxu ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/echoxu
  chmod 440 /etc/sudoers.d/echoxu
}


# ssh 配置
configSSH(){
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.`date +%Y%m%d%H%M%S`
  sed -i 's%#Port 22%Port 51888%' /etc/ssh/sshd_config
  sed -i 's%#PermitRootLogin yes%PermitRootLogin no%' /etc/ssh/sshd_config
  sed -i 's%#PermitEmptyPasswords no%PermitEmptyPasswords no%' /etc/ssh/sshd_config
  sed -i 's%#UseDNS yes%UseDNS no%' /etc/ssh/sshd_config
  sed -i 's%GSSAPIAuthentication yes%GSSAPIAuthentication no%' /etc/ssh/sshd_config
  sed -i 's%#PubkeyAuthentication yes%PubkeyAuthentication yes%' /etc/ssh/sshd_config
  sed -i 's%PasswordAuthentication yes%PasswordAuthentication no%' /etc/ssh/sshd_config
  systemctl restart sshd
}


# 解决 DNS 连接慢的问题
fixSlowDNS(){
  case "$PACKER_BUILDER_TYPE" in
  virtualbox-iso|virtualbox-ovf)
    # Add 'single-request-reopen' so it is included when /etc/resolv.conf is generated
    # https://access.redhat.com/site/solutions/58625 (subscription required)
    # http://www.linuxquestions.org/questions/showthread.php?p=4399340#post4399340

    echo 'RES_OPTIONS="single-request-reopen"' >>/etc/sysconfig/network;

    echo 'Slow DNS fix applied (single-request-reopen)';
    ;;

  esac
}


# 最常用的优化操作
base(){
  # 关闭 selinux 功能（ 需重启）
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

  # 精简开机项，与上一项可添加到 ks.cfg 中。
  chkconfig ——list|grep 3：on|grep -vE "crond|sshd|network|rsyslog|sysstat" |awk '{print "chkconfig " $1 " off"}'

  # 设置 linux 的命令行历史记录数
  echo 'export HISTFILESIZE=5' >>/etc/profile
  echo 'HISTSIZE=5' >>/etc/profile
  #source /etc/profile

  # 调整 linux 系统文件描述符数量
  echo '*   -   nofile    65535 ' >>/etc/security/limits.conf

  # 锁定关键系统文件，防止被提权篡改
  chattr +i /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/inittab

  # 防火墙配置
  firewall-cmd --zone=public --add-port={51888,22}/tcp --permanent
  firewall-cmd --remove-service={http,ssh} --permanent
  firewall-cmd --reload

  # linux 服务器内核参数优化
  # 隐藏 linux 版本信息显示
  # 时间同步
  # 网络配置
  # 日志分割
}


# 删除不需要的字体，只保留 en_US.utf8
delete_locale(){
  # https://unix.stackexchange.com/questions/90006/how-do-i-reduce-the-size-of-locale-archive
  localedef --delete-from-archive $(localedef --list-archive | grep -v -i en_US.utf8 | xargs)
  mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
  build-locale-archive  # 此命令会导致用户退出当前 shell

  echo ""

}


main(){
  echo ""
  rename_eth0
  echo "------------------------ 已修改网卡名为 eth0 并设置 grub 等待时间 -----------------------"

  echo ""
  yumConfig
  echo "------------------------ 已将 yum 源修改为阿里云 yum 源 -----------------------"

  echo ""
  installSoftware
  echo "-------------------------- 已完成安装常用软件（vim、wget等）操作 -------------------------"

  echo ""
  delUser
  echo "--------------------- 已将多余用户进行删除 ------------------- "

  echo ""
  fixSlowDNS
  echo "--------------------- 已解决 DNS 连接慢的问题 ------------------------"

  echo ""
  base
  echo "--------------------- Linux 基础优化，包括设置：历史记录、最大文件数等操作已完成 ------------------------"

  #userNOPASSWD && action "用户无密码登录脚本执行状态:" /bin/true || action "用户无密码登录脚本执行状态:" /bin/false
  #echo -e "\033[36m------------------------ 已将用户添加进 sudo 并使其可无密码登录 -----------------------\033[0m"

  echo ""
  delete_locale  # 不要移动，此函数只能放置在 shutdown -r now 命令之前
  echo "------------------- 只保留 en_US.utf8 字符集, 删除不需要的字体 ------------------"
  
  echo ""
  echo "------------------- 虚拟机将重启，请不要关闭电源 ------------------"

  # shutdown -r now 
  # https://github.com/hashicorp/packer/issues/3148
  reboot # yum update 后生成了多余的 linux-firmware、新的内核、以及 不需要的字体库，只有 重启 才能获取到它们的结果
}


main
