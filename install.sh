#!/bin/bash -ev
fdisk -t dos /dev/sda << EOF
o
n
p


+2M

n
p


+128M

n
p



w
y
EOF
mkfs.ext2 /dev/sda2
mkfs.ext4 /dev/sda3
mkdir -p /mnt/gentoo
mount /dev/sda3 /mnt/gentoo
mkdir -p /boot
mount /dev/sda2 /boot
cd /mnt/gentoo
mkdir -p /mnt/gentoo/tmp
chmod 1777 /mnt/gentoo/tmp
# you can also host locally to not get banned by the gentoo servers...
#wget http://10.0.2.2:3333/stage3-amd64-20180320T214502Z.tar.xz
wget http://distfiles.gentoo.org/releases/amd64/autobuilds/20180320T214502Z/stage3-amd64-20180320T214502Z.tar.xz
tar xJpf stage3-*.tar.* --xattrs-include='*.*' --numeric-owner
rm -rf ./*.tar*
echo "MAKEOPTS=\"-j4\"" >> /mnt/gentoo/etc/portage/make.conf
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

install_chroot() {
	. /etc/profile
	mkdir -p /usr/portage
	emerge-webrsync
	emerge --sync
	time emerge  --update --deep --newuse @world
	echo "US/Eastern" > /etc/timezone
	emerge --config sys-libs/timezone-data
	echo "en_US ISO-8859-1" >> /etc/locale.gen
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	eselect locale set 5
	env-update && source /etc/profile
	emerge sys-kernel/gentoo-sources
	emerge sys-apps/pciutils
	cd /usr/src/linux
	time make defconfig
	time make && make modules_install && make install
	emerge sys-kernel/genkernel
	time genkernel --lvm --install initramfs
	emerge sys-kernel/linux-firmware
	echo "/dev/sda2   /boot        ext2    defaults,noatime     0 2" >> /etc/fstab
	echo "/dev/sda3   /            ext4    noatime              0 1" >> /etc/fstab
	echo "hostname=\"gentoo\"" > /etc/conf.d/hostname
	echo "config_eth0=\"dhcp\"" > /etc/conf.d/net
	cd /etc/init.d
	ln -s net.lo net.eth0
	rc-update add net.eth0 default
	rc-update add sshd default
	emerge net-misc/dhcpcd
	emerge sys-boot/grub:2
	grub-install /dev/sda
	grub-mkconfig -o /boot/grub/grub.cfg
	echo -e "packer\npacker\n" | passwd root
}
export -f install_chroot
chroot /mnt/gentoo /bin/bash -c "install_chroot"
