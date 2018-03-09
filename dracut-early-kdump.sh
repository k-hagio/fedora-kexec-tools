#! /bin/sh

KEXEC=/sbin/kexec
standard_kexec_args="-p"

EARLY_KDUMP_INITRD=""
EARLY_KDUMP_KERNEL=""
EARLY_KDUMP_CMDLINE=""
EARLY_KDUMP_KERNELVER=""
EARLY_KEXEC_ARGS=""

#source lib and configure
. /lib/dracut-lib.sh
. /lib/kdump-lib.sh
. /etc/sysconfig/kdump

prepare_parameters()
{
    local cmdline id

    if [ -z "$EARLY_KDUMP_CMDLINE" ]; then
        cmdline=$(cat /proc/cmdline)
    else
        cmdline=${EARLY_KDUMP_CMDLINE}
    fi

    cmdline=$(remove_cmdline_param "$cmdline" crashkernel panic_on_warn)
    cmdline=$(remove_cmdline_param "$cmdline" ${KDUMP_COMMANDLINE_REMOVE})

    # Always remove "root=X", as we now explicitly generate all kinds
    # of dump target mount information including root fs.
    #
    # We do this before KDUMP_COMMANDLINE_APPEND, if one really cares
    # about it(e.g. for debug purpose), then can pass "root=X" using
    # KDUMP_COMMANDLINE_APPEND.
    cmdline=$(remove_cmdline_param "$cmdline" root)

    # With the help of "--hostonly-cmdline", we can avoid some interitage.
    cmdline=$(remove_cmdline_param "$cmdline" rd.lvm.lv rd.luks.uuid rd.dm.uuid rd.md.uuid fcoe)
    cmdline="${cmdline} ${KDUMP_COMMANDLINE_APPEND}"
    id=$(get_bootcpu_apicid)
    if [ ! -z ${id} ] ; then
        cmdline=$(append_cmdline "${cmdline}" disable_cpu_apicid ${id})
    fi
    EARLY_KDUMP_CMDLINE=$cmdline

    if [ -z "$KDUMP_BOOTDIR" ]; then
        if ! is_atomic || [ "$(uname -m)" = "s390x" ]; then
                KDUMP_BOOTDIR="/boot"
        else
                eval $(cat /proc/cmdline| grep "BOOT_IMAGE" | cut -d' ' -f1)
                KDUMP_BOOTDIR="/boot"$(dirname $BOOT_IMAGE)
        fi
    fi

    #make early-kdump kernel string
    if [ -z "$EARLY_KDUMP_KERNELVER" ]; then
        EARLY_KDUMP_KERNELVER=`uname -r`
    fi
    EARLY_KDUMP_KERNEL="${KDUMP_BOOTDIR}/${KDUMP_IMG}-${EARLY_KDUMP_KERNELVER}${KDUMP_IMG_EXT}"

    #make early-kdump initrd string
    EARLY_KDUMP_INITRD="${KDUMP_BOOTDIR}/initramfs-${EARLY_KDUMP_KERNELVER}kdump.img"
}

early_kdump_load()
{
    check_kdump_feasibility
    if [ $? -ne 0 ]; then
        return 1
    fi

    if is_fadump_capable; then
        echo "early kdump doesn't support fadump: [WARNING]"
        return 1
    fi

    check_current_kdump_status
    if [ $? == 0 ]; then
        return 1
    fi

    prepare_parameters

    ARCH=`uname -m`
    if [ "$ARCH" == "i686" -o "$ARCH" == "i386" ]
    then
        need_64bit_headers
        if [ $? == 1 ]
        then
            FOUND_ELF_ARGS=`echo $EARLY_KEXEC_ARGS | grep elf32-core-headers`
            if [ -n "$FOUND_ELF_ARGS" ]
            then
                echo -n "Warning: elf32-core-headers overrides correct elf64 setting"
                echo
            else
                EARLY_KEXEC_ARGS="$EARLY_KEXEC_ARGS --elf64-core-headers"
            fi
        else
            FOUND_ELF_ARGS=`echo $EARLY_KEXEC_ARGS | grep elf64-core-headers`
            if [ -z "$FOUND_ELF_ARGS" ]
            then
                EARLY_KEXEC_ARGS="$EARLY_KEXEC_ARGS --elf32-core-headers"
            fi
        fi
    fi

    #secure boot
    if is_secure_boot_enforced; then
        echo "Secure Boot is enabled. Using kexec file based syscall."
        EARLY_KEXEC_ARGS="$EARLY_KEXEC_ARGS -s"
    fi

    $KEXEC ${EARLY_KEXEC_ARGS} $standard_kexec_args \
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
