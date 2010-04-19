#!/bin/bash

# A basic script to setup a PXE server enviroment for Arch Linux live-media.
# Contributed by Gerardo Exequiel Pozzi <vmlinuz386@yahoo.com.ar>

# Requires: dnsmasq and nbd packages

# usage example: archiso-pxe-server [ip] [bootdevice/isoimage]

BOOT=/bootmnt/boot
TFTPBOOT=/var/tftpboot

IP="$1"
ISO="$2"

IP_ETH0=`ifconfig eth0 | awk -F":| +" '/inet addr/{print $4}'`
if grep archisolabel /proc/cmdline > /dev/null; then
	LABEL=`sed "s/.\+archisolabel=\([^ ]\+\).\+/\1/" /proc/cmdline`
else
	LABEL=""
fi

usage()
{
	echo
	echo "archiso-pxe-server [ip] [bootdevice]"
	echo
	echo " options:"
	echo "    [ip] ip address of the local interface to serve (default use ip of eth0)"
	echo "    [bootdevice] boot device of Arch Linux Live media (for example /dev/cdrom)"
	echo
}

copy_files()
{
	if [ ! -d $TFTPBOOT ]; then
		mkdir -p $TFTPBOOT/boot/i686
		mkdir -p $TFTPBOOT/boot/x86_64
		mkdir -p $TFTPBOOT/pxelinux.cfg
		[ -f $BOOT/vmlinuz26 ] && cp $BOOT/vmlinuz26 $TFTPBOOT/boot
		[ -f $BOOT/archiso.img ] && cp $BOOT/archiso.img $TFTPBOOT/boot
		[ -f $BOOT/i686/vmlinuz26 ] && cp $BOOT/i686/vmlinuz26 $TFTPBOOT/boot/i686
		[ -f $BOOT/i686/archiso.img ] && cp $BOOT/i686/archiso.img $TFTPBOOT/boot/i686
		[ -f $BOOT/x86_64/vmlinuz26 ] && cp $BOOT/x86_64/vmlinuz26 $TFTPBOOT/boot/x86_64
		[ -f $BOOT/x86_64/archiso.img ] && cp $BOOT/x86_64/archiso.img $TFTPBOOT/boot/x86_64
		cp $BOOT/memtest $TFTPBOOT/boot
		cp $BOOT/x86test $TFTPBOOT/boot
		cp $BOOT/splash.png $TFTPBOOT/boot
		cp $BOOT/isolinux/pxelinux.0 $TFTPBOOT
		cp $BOOT/isolinux/chain.c32 $TFTPBOOT
		cp $BOOT/isolinux/reboot.c32 $TFTPBOOT
		cp $BOOT/isolinux/vesamenu.c32 $TFTPBOOT
		sed 's|IPAPPEND 0|IPAPPEND 3|g' \
		$BOOT/isolinux/isolinux.cfg > \
		$TFTPBOOT/pxelinux.cfg/default
	fi
}

start_pxe_server()
{
	dnsmasq \
	--enable-tftp \
	--tftp-root=$TFTPBOOT \
	--dhcp-boot=/pxelinux.0,"${IP}" \
	--dhcp-range=${IP%.*}.2,${IP%.*}.254,86400
}

start_nbd_server()
{
	nbd-server 9040 ${ISO} -r
}

check_parameters()
{
	if [ -z "$IP_ETH0" -a -z "$IP" ]; then
		echo "ERROR: missing IP address"
		usage
		exit 1
	else
		IP=$IP_ETH0
	fi

	if [ -z "$LABEL" -a -z "$ISO" ]; then
		echo "ERROR: can't determine boot device, please specify on command line"
		usage
		exit 1
	else
		ISO="/dev/disk/by-label/$LABEL"
	fi
}

check_parameters
copy_files
start_pxe_server
start_nbd_server

