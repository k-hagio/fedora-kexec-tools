#!/bin/bash

check() {
    if [ ! -f /etc/sysconfig/kdump ] || [ ! -f /lib/kdump/kdump-lib.sh ] || [ "$IN_KDUMP" = 1 ]
    then
        return 1
    fi
    return 0
}

depends() {
    echo "base shutdown"
    return 0
}

install() {
    . /etc/sysconfig/kdump
    [ -z "${KDUMP_BOOTDIR}" ]   && KDUMP_BOOTDIR=/boot
    [ -z "${KDUMP_KERNELVER}" ] && KDUMP_KERNELVER=$(uname -r)
    inst_simple "${KDUMP_BOOTDIR}/${KDUMP_IMG}-${KDUMP_KERNELVER}${KDUMP_IMG_EXT}" \
        "${KDUMP_BOOTDIR}/${KDUMP_IMG}-${KDUMP_KERNELVER}${KDUMP_IMG_EXT}"
    inst_simple "${KDUMP_BOOTDIR}/initramfs-${KDUMP_KERNELVER}kdump.img" \
        "${KDUMP_BOOTDIR}/initramfs-${KDUMP_KERNELVER}kdump.img"
    inst_simple "/etc/sysconfig/kdump" "/etc/sysconfig/kdump"
    inst_simple "/usr/sbin/kexec" "/usr/sbin/kexec"
    inst_script "/lib/kdump/kdump-lib.sh" "/lib/kdump-lib.sh"
    inst_script "$moddir/early-kdump.sh" "/usr/bin/early-kdump"
    inst_simple "$moddir/early-kdump.service" "${systemdsystemunitdir}/early-kdump.service"
    ln_r "${systemdsystemunitdir}/early-kdump.service" "${systemdsystemunitdir}/initrd.target.wants/early-kdump.service"
}
