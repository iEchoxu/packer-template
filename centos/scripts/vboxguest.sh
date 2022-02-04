#!/bin/sh -eux

# set a default HOME_DIR environment variable if not set
HOME_DIR="${HOME_DIR:-/home/vagrant}";

case "$PACKER_BUILDER_TYPE" in
  virtualbox-iso|virtualbox-ovf)
    VER="`cat $HOME_DIR/.vbox_version`";
    ISO="VBoxGuestAdditions_$VER.iso";

    # mount the ISO to /media/VBoxGuestAdditions
    mkdir /media/VBoxGuestAdditions
    mount -o loop,ro $HOME_DIR/$ISO /media/VBoxGuestAdditions

    echo "------------------------ installing deps necessary to compile kernel modules ------------------------"
    # We install things like kernel-headers here vs. kickstart files so we make sure we install them for the updated kernel not the stock kernel
    if [ -f "/bin/dnf" ]; then
        dnf install -y --skip-broken bzip2 kernel-devel || true # not all these packages are on every system
    elif [ -f "/bin/yum" ] || [ -f "/usr/bin/yum" ]; then
        yum install -y --skip-broken bzip2 kernel-devel || true # not all these packages are on every system
    elif [ -f "/usr/bin/apt-get" ]; then
        apt-get install -y build-essential dkms bzip2 tar linux-headers-`uname -r`
    fi

    echo "------------------------ installing the vbox additions ------------------------"
    # this install script fails with non-zero exit codes for no apparent reason so we need better ways to know if it worked
    sh /media/VBoxGuestAdditions/VBoxLinuxAdditions.run || true

    # lsmod |grep vbox 也可查看是否安装成功
    if ! modinfo vboxsf >/dev/null 2>&1; then
         echo "------------ Cannot find vbox kernel module. Installation of guest additions unsuccessful! ------------"
         exit 1
    fi

    echo "------------------------ unmounting and removing the vbox ISO ------------------------"
    umount /media/VBoxGuestAdditions
    rmdir /media/VBoxGuestAdditions
    rm -f $HOME_DIR/*.iso

    echo "------------ removing kernel dev packages and compilers we no longer need ------------"
    if [ -f "/bin/dnf" ]; then
        dnf remove -y gcc cpp kernel-headers kernel-devel kernel-uek-devel
    elif [ -f "/bin/yum" ] || [ -f "/usr/bin/yum" ]; then
        yum remove -y gcc cpp kernel-headers kernel-devel
    elif [ -f "/usr/bin/apt-get" ]; then
        apt-get remove -y build-essential gcc g++ make libc6-dev dkms linux-headers-`uname -r`
    fi

    echo "------------------------ removing leftover logs ------------------------"
    rm -rf /var/log/vboxadd*
    ;;
esac
