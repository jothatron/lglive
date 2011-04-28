#!/bin/bash

# A basic script to setup a PXE server enviroment for Arch Linux live-media.
# Contributed by Gerardo Exequiel Pozzi <vmlinuz386@yahoo.com.ar>

# Requires: dnsmasq and nbd packages

TMPDIR=/tmp/archiso-pxe-server
VERSION=20100925

iso_umount() {
    trap - 0 1 2 15
    umount $TMPDIR/mnt
    rmdir $TMPDIR/mnt
}

iso_mount() {
    mkdir -p $TMPDIR/mnt
    trap 'iso_umount' 0 1 2 15
    mount $ISO $TMPDIR/mnt -o ro,loop
}

show_help()
{
    exitvalue=${1}
    echo
    echo "archiso-pxe-server version $VERSION"
    echo
    echo "archiso-pxe-server [options]"
    echo
    echo " options:"
    echo "    -i [ip]         ip address of the local interface to serve"
    echo "                    (default: $IP )"
    echo "    -d [device]     boot device of Arch Linux Live media"
    echo "                    (default: $DEVICE )"
    echo "    -s [isofile]    Arch Linux Live media iso image"
    echo "                    (default: $ISO )"
    echo "    -b [boot]       path to /boot from archiso"
    echo "                    (default: $BOOT )"
    echo "    -t [tftpboot]   path to setup PXE enviroment"
    echo "                    (default: $TMPDIR )"
    echo
    exit ${exitvalue}
}

copy_files()
{
    if [ -f $BOOT/vmlinuz26 ]; then
        mkdir -p $TMPDIR/boot
        cp $BOOT/vmlinuz26 $TMPDIR/boot
        cp $BOOT/archiso.img $TMPDIR/boot
    else
        mkdir -p $TMPDIR/boot/i686
        mkdir -p $TMPDIR/boot/x86_64
        cp $BOOT/i686/vmlinuz26 $TMPDIR/boot/i686
        cp $BOOT/i686/archiso.img $TMPDIR/boot/i686
        cp $BOOT/x86_64/vmlinuz26 $TMPDIR/boot/x86_64
        cp $BOOT/x86_64/archiso.img $TMPDIR/boot/x86_64
    fi
    mkdir -p $TMPDIR/pxelinux.cfg
    cp $BOOT/memtest $TMPDIR/boot
    cp $BOOT/splash.png $TMPDIR/boot

    # Keep this for now for compatibility with 2010.05
    if [ -f $BOOT/isolinux/pxelinux.0 ]; then
        cp $BOOT/x86test $TMPDIR/boot
        cp $BOOT/isolinux/pxelinux.0 $TMPDIR
        cp $BOOT/isolinux/chain.c32 $TMPDIR
        cp $BOOT/isolinux/reboot.c32 $TMPDIR
        cp $BOOT/isolinux/vesamenu.c32 $TMPDIR
        sed 's|IPAPPEND 0|IPAPPEND 3|g' \
            $BOOT/isolinux/isolinux.cfg > \
            $TMPDIR/pxelinux.cfg/default
    else
        cp $BOOT/syslinux/pxelinux.0 $TMPDIR
        cp $BOOT/syslinux/chain.c32 $TMPDIR
        cp $BOOT/syslinux/hdt.c32 $TMPDIR
        cp $BOOT/syslinux/reboot.c32 $TMPDIR
        cp $BOOT/syslinux/vesamenu.c32 $TMPDIR
        cp -r $BOOT/syslinux/hdt $TMPDIR
        sed 's|^#IPAPPEND|IPAPPEND|g' \
            $BOOT/syslinux/syslinux.cfg > \
            $TMPDIR/pxelinux.cfg/default
    fi
}

start_pxe_server()
{
    pkill dnsmasq > /dev/null 2>&1
    dnsmasq \
        --port=0 \
        --enable-tftp \
        --tftp-root=$TMPDIR \
        --dhcp-boot=/pxelinux.0,"${IP}" \
        --dhcp-range=${IP%.*}.2,${IP%.*}.254,86400
}

start_nbd_server()
{
    pkill nbd-server > /dev/null 2>&1
    echo "[generic]" > $TMPDIR/nbd-server.conf
    echo "[archiso]" >> $TMPDIR/nbd-server.conf
    echo "    readonly = true" >> $TMPDIR/nbd-server.conf
    echo "    exportname = ${DEVICE}" >> $TMPDIR/nbd-server.conf
    nbd-server -C $TMPDIR/nbd-server.conf
}

guess_enviroment()
{
    if grep archisolabel /proc/cmdline > /dev/null; then
        DEVICE="/dev/disk/by-label/"`sed "s/.\+archisolabel=\([^ ]\+\).\+/\1/" /proc/cmdline`
        BOOT=/bootmnt/boot
    fi

    IP=`ifconfig eth0 | awk -F":| +" '/inet addr/{print $4}'`
}

check_parameters()
{
    if [ -z "$IP" ]; then
        echo "ERROR: missing IP address"
        show_help 1
    fi

    if [ -n "$ISO" ]; then
        iso_mount
        DEVICE=`readlink -f $ISO`
        BOOT="$TMPDIR/mnt/boot"
    fi

    if [ -z "$DEVICE" ]; then
        echo "ERROR: can't determine boot device, please specify on command line"
        show_help 1
    fi
}

guess_enviroment

while getopts 'i:s:d:b:t:h' arg; do
    case "${arg}" in
        i) IP="${OPTARG}" ;;
        s) ISO="${OPTARG}" ;;
        d) DEVICE=`readlink -f ${OPTARG}` ;;
        b) BOOT="${OPTARG}" ;;
        t) TMPDIR="${OPTARG}" ;;
        h) show_help 0 ;;
        *) echo; echo "*ERROR*: invalid argument '${arg}'"; show_help 1 ;;
    esac
done

check_parameters
copy_files
start_pxe_server
start_nbd_server

