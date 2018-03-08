#! /bin/sh

KEXEC=/sbin/kexec
standard_kexec_args="-p"

#source lib and configure
. /lib/dracut-lib.sh
. /etc/sysconfig/kdump 

is_atomic()
{
    grep -q "ostree" /proc/cmdline
}

if [ -z "$KDUMP_BOOTDIR" ]; then
    if ! is_atomic || [ "$(uname -m)" = "s390x" ]; then
        KDUMP_BOOTDIR="/boot"
    else
        eval $(cat /proc/cmdline | grep "BOOT_IMAGE" | cut -d' ' -f1)
        KDUMP_BOOTDIR="/boot"$(dirname $BOOT_IMAGE)
    fi
fi

EARLY_KDUMP_INITRD="${KDUMP_BOOTDIR}/initramfs-`uname -r`kdump.img"
EARLY_KDUMP_KERNEL="${KDUMP_BOOTDIR}/${KDUMP_IMG}-`uname -r`${KDUMP_IMG_EXT}"
EARLY_KDUMP_CMDLINE=`cat /proc/cmdline | sed -e 's/crashkernel=[^ ]*//'`
EARLY_KDUMP_CMDLINE="${EARLY_KDUMP_CMDLINE} ${KDUMP_COMMANDLINE_APPEND}"


check_crash_mem_reserved()
{
    local mem_reserved

    mem_reserved=$(cat /sys/kernel/kexec_crash_size)
    if [ $mem_reserved -eq 0 ]; then
        echo "No memory reserved for crash kernel"
        return 1
    fi

    return 0
}

check_kdump_feasibility()
{
    if [ ! -e /sys/kernel/kexec_crash_loaded ]; then
        echo "Kdump is not supported on this kernel"
        return 1
    fi
    check_crash_mem_reserved
    return $?
}

check_earlykdump_loaded()
{
    local early_kdump_loaded
    early_kdump_loaded=$(cat /sys/kernel/kexec_crash_loaded)
    if [ $early_kdump_loaded -eq 0 ]; then
        return 0
    fi

    return 1
}

early_kdump_load()
{
    check_kdump_feasibility
    if [ $? -ne 0 ]; then
        return 1
    fi

    check_earlykdump_loaded
    if [ $? -ne 0 ]; then
        return 1
    fi

    $KEXEC $standard_kexec_args \
        --command-line="$EARLY_KDUMP_CMDLINE" \
        --initrd=$EARLY_KDUMP_INITRD $EARLY_KDUMP_KERNEL

    if [ $? == 0 ]; then
        echo "kexec: loaded early-kdump kernel"
        return 0
    else
        echo "kexec: failed to load early-kdump kernel"
        return 1
    fi

}

setearlykdump()
{
    if getargbool 0 rd.early-kdump; then
        echo "early-kdump is enabled."
        early_kdump_load
    else
        echo "early-kdump is not enabled by default."
    fi

    return 0
}

setearlykdump

