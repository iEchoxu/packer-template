> 用 Packer 自动化构建基础镜像

## 如何使用？

- 目录介绍
  - builds：用于存放 Packer 打包后的 Box 文件
  - `centos`：用于构建 `Centos` 镜像所需的 Packer 配置文件以及脚本文件
  - _common：用于存放一些公共文件
- 修改点东西
  - 将 `centos/http/sshkey`  里的 `id_rsa_vagrant.pub` 替换为你自己的 `sshkey` 文件
  - 修改 `centos/variables-centos7.9.json` 里的 `ssh_username`、 `ssh_password` 以及 `ssh_pubkey`
  - 修改 `centos/http/7/ks.cfg` 里的 `rootpw --iscrypted` 后面的值为加密后的 root 密码，可通过  `openssl passwd -1 "vagrant"` 得到加密后的密码
  - 修改 `centos/http/7/ks.cfg` 里的 `user --groups=vagrant --name=vagrant --password=$1$CLP8Fsi9$G2YnFrW34CLu16058XzPv0 --iscrypted --gecos="vagrant"` 里的用户名和密码，通过  `openssl passwd -1 "vagrant"` 得到加密后的密码
  - 替换  `centos/http/7/ks.cfg` 里的所有 vagrant 用户名为你自己定义的用户名，默认用户名为 vagrant ，密码为 vagrant
  - 修改 `centos/scripts/base.sh` --- `设置 vagrant 账号无密码且拥有 sudo 权限` 里的 vagrant 为你的用户名
  - 替换 `centos/scripts/cleanall.sh` 里的 vagrant 为你的用户名
  - 替换 `centos/scripts/vboxguest.sh` 里的 vagrant 为你的用户名

- 操作步骤（需要安装 Packer、`KVM/Virtualbox/VMware`）
  - 先进入到 `Centos` 目录下
  - 然后执行 `packer build -var-file variables-centos7.9.json centos-qemu.json`
  - 待打包完成后在 builds 目录下找到生成的 Box 文件，然后可用 `vagrant box add xxxx.box` 添加使用

