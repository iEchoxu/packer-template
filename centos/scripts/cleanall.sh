#!/bin/sh -eux

major_version="`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release | awk -F. '{print $1}'`"


# 生成 machine-id
clear_machineID(){
  if [ "$major_version" -ge 7 ]; then
    rm -f /var/lib/systemd/random-seed

    # Wipe netplan machine-id (DUID) so machines get unique ID generated on boot
    truncate -s 0 /etc/machine-id
    #systemd-machine-id-setup
  fi

  echo "ok"

  echo ""
}


# 删除旧内核以及 linux-firmware
remove_oldKernel(){
  if [ "$major_version" -ge 8 ]; then
    dnf -y autoremove
    dnf -y remove -y $(dnf repoquery --installonly --latest-limit=-1 -q)
  else
    yum -y remove linux-firmware
    yum -y remove $(rpm -qa | grep kernel | grep -v $(uname -r))
  fi

  echo ""
}


# ssh 配置（因为修改了 ssh 端口，和 packer 配置文件中的端口信息不一致，所以添加在此处）
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

  echo ""
}


cleanall(){
  # 删除帮助文档等
  rm -rf /usr/share/locale/*
  rm -rf /usr/share/man/*
  rm -rf /usr/share/doc/*

  # 删除用户目录下的文件
  rm -rf /home/vagrant/*
  rm -rf /root/{anaconda-ks.cfg,original-ks.cfg,ks-post.log}

  # 删除启动界面背景图
  rm -rf /usr/share/backgrounds/*

  # 删除日志和临时文件
  find /var/log/ -name *.log -exec rm -f {} \;
  rm -rf /tmp/* /var/tmp/*

  # 删除 shell 历史记录
  unset HISTFILE
  rm -f /root/.bash_history
  rm -rf /home/vagrant/.bash_history

  # 重构 rpmdb
  rpmdb --rebuilddb
  rm -f /var/lib/rpm/__db*

  # 清除 yum 缓存
  yum -y --enablerepo='*'  clean all


  # 删除默认的 22 端口
  firewall-cmd --zone=public  --remove-port=22/tcp  --permanent
  firewall-cmd --reload

  echo ""
}


# 防止VMware克隆虚拟机后网络不能正常使用
fix_clone_err(){
  for ifcfg in `ls /etc/sysconfig/network-scripts/ifcfg-* |grep -v ifcfg-lo` ; do
    sed -i '/^HWADDR/d' "$ifcfg";
    sed -i '/^UUID/d' "$ifcfg";
  done

  echo ""
}


# 压缩 / 以及 /boot、/swap 分区磁盘空间，此操作可减小 box 体积
compressDisk(){
  count=$(df --sync -kP / | tail -n1  | awk -F ' ' '{print $4}')
  count=$((count -= 1))
  dd if=/dev/zero of=/tmp/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
  rm /tmp/whitespace

  count=$(df --sync -kP /boot | tail -n1 | awk -F ' ' '{print $4}')
  count=$((count -= 1))
  dd if=/dev/zero of=/boot/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
  rm /boot/whitespace
  
  # Whiteout swap
  # Clear out swap and disable until reboot
  set +e
  swapuuid="`/sbin/blkid -o value -l -s UUID -t TYPE=swap`";
  case "$?" in
      2|0) ;;
      *) exit 1 ;;
  esac
  set -e

  if [ "x${swapuuid}" != "x" ]; then
      # Whiteout the swap partition to reduce box size
      # Swap is disabled till reboot
      # swappart=`cat /proc/swaps | tail -n1 | awk -F ' ' '{print $1}'`
      swappart="`readlink -f /dev/disk/by-uuid/$swapuuid`";
      /sbin/swapoff "$swappart" || true;
      dd if=/dev/zero of="$swappart" bs=1M || echo "dd exit code $? is suppressed";
      /sbin/mkswap -U "$swapuuid" "$swappart";
  fi

  echo ""
}


# 同步到硬盘
syncdisk(){
  sync;

  echo ""
}


main(){
  echo ""
  clear_machineID
  echo "--------------------- 已清除原有的 machine-id，下次启动会自动生成 ---------------------"
 
  echo ""
  fix_clone_err
  echo "--------------------- 清除网卡中的硬件信息及 UUID，防止虚拟机克隆时启动报错 ---------------------"

  echo ""
  configSSH
  echo "--------------------- SSH 配置已完成修改 ---------------------"

  echo ""
  echo "--------------------- 没清理之前的磁盘占用情况： ---------------------"
  df -h
 
  echo ""
  remove_oldKernel
  echo "--------------------- 已移除旧的内核及删除非必须软件：linux-firmware ---------------------"

  echo ""
  cleanall
  echo "--------------------- 为了节省磁盘空间，删除 yum 缓存、帮助文档、临时文件等 ---------------------"

  echo ""
  echo "--------------------- 清理之后的磁盘占用情况： ---------------------"
  df -h

  echo ""
  compressDisk
  echo "--------------------- 压缩磁盘空间，减小打包后的 Box 体积 ---------------------"

  echo ""
  syncdisk
  echo "--------------------- 已将修改同步到硬盘，系统瘦身完成 ---------------------"
}


main
