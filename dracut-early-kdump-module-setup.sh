#!/bin/bash

check() {
    if [ ! -f /etc/sysconfig/kdump ] || [ ! -f /lib/kdump/kdump-lib.sh ]
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
    inst_simple "/etc/sysconfig/kdump" "/etc/sysconfig/kdump"
    inst_simple "/usr/sbin/kexec" "/usr/sbin/kexec"
    inst_script "/lib/kdump/kdump-lib.sh" "/lib/kdump-lib.sh"
    inst_script "$moddir/early-kdump.sh" "/usr/bin/early-kdump"
    inst_simple "$moddir/early-kdump.service" "${systemdsystemunitdir}/early-kdump.service"
    ln_r "${systemdsystemunitdir}/early-kdump.service" "${systemdsystemunitdir}/initrd.target.wants/early-kdump.service"
}
