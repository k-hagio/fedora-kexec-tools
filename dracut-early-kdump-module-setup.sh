#!/bin/bash

#the function should only return 0 in hostonly mode
check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_simple "/etc/sysconfig/kdump" "/etc/sysconfig/kdump"
    inst_script "$moddir/early-kdump.sh" "/usr/bin/early-kdump"
    inst_simple "$moddir/early-kdump.service" "${systemdsystemunitdir}/early-kdump.service"
    ln_r "${systemdsystemunitdir}/early-kdump.service" "${systemdsystemunitdir}/initrd.target.wants/early-kdump.service"
}
