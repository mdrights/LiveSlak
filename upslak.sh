#!/bin/bash
#
# Copyright 2017  Eric Hameleers, Eindhoven, NL
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# -----------------------------------------------------------------------------
#
# This script can perform the following changes on
# the USB version of on Slackware Live Edition.
# - upgrade the kernel and modules
# - add network support modules for PXE boot (if missing)
# - increase (or decrease) USB wait time during boot
# - replace the Live init script inside the initrd image
# - move current persistence data to a new squashfs module in 'addons'
#
# -----------------------------------------------------------------------------

# Be careful:
set -e

# Limit the search path:
export PATH="/usr/sbin:/sbin:/usr/bin:/bin"

# ---------------------------------------------------------------------------
# START possible tasks to be executed by the script:
# ---------------------------------------------------------------------------

# By default do not move persistence data into a new Live module:
CHANGES2SXZ=0

# Replace the live 'init' script with the file $LIVEINIT:
LIVEINIT=""

# Do we need to add network support? This can be enforced through commandline,
# otherwise will be determined by examining the original kernelmodules:
NETSUPPORT=""

# This will be set to '1' if the user wants to restore the backups of the
# previous kernel and modules:
RESTORE=0

# Set default for 'do we update the kernel':
UPKERNEL=0

# Do not change usb wait time by default:
WAIT=-1

# ---------------------------------------------------------------------------
# END possible tasks to be executed by the script:
# ---------------------------------------------------------------------------

# Determine whether the USB stick has a supported kernel configuration
# i.e. one active and optionally one backup kernel plus mmodules:
SUPPORTED=1

# Values obtained from the init script on the USB:
DISTRO=""
LIVE_HOSTNAME=""
LIVEMAIN=""
LIVEUID=""
MARKER=""
MEDIALABEL=""
PERSISTENCE=""
VERSION=""

# By default we make a backup of your old kernel/modules when adding new ones:
KBACKUP=1

# Does the initrd contain an old kernel that we can restore?
# The 'read_initrd' routing may set this to '0':
KRESTORE=1

# Timeout when scanning for inserted USB device, 30 seconds by default,
# but this default can be changed from outside the script:
SCANWAIT=${SCANWAIT:-30}

# By default do not show file operations in detail:
VERBOSE=0

# Set to '1' if we are to scan for device insertion:
SCAN=0

# Minimim free space (in MB) we want to have left in any partition
# after we are done.
# The default value can be changed from the environment:
MINFREE=${MINFREE:-10}

# Variables to store content from an initrd we are going to refresh:
OLDKERNELSIZE=""
OLDKMODDIRSIZE=""
OLDKVER=""
OLDWAIT=""

# Record the version of the new kernel:
KVER=""

# Define ahead of time, so that cleanup knows about them:
IMGDIR=""
KERDIR=""
USBMNT=""
EFIMNT=""

# These tools are required by the script, we will check for their existence:
REQTOOLS="cpio gdisk inotifywait strings xz"

# Compressor used on the initrd ("gzip" or "xz --check=crc32");
# Note that the kernel's XZ decompressor does not understand CRC64:
COMPR="xz --check=crc32"

# -- START: Taken verbatim from make_slackware_live.sh -- #
# List of kernel modules required for a live medium to boot properly;
# Lots of HID modules added to support keyboard input for LUKS password entry:
KMODS=${KMODS:-"squashfs:overlay:loop:xhci-pci:ohci-pci:ehci-pci:xhci-hcd:uhci-hcd:ehci-hcd:mmc-core:mmc-block:sdhci:sdhci-pci:sdhci-acpi:usb-storage:hid:usbhid:i2c-hid:hid-generic:hid-apple:hid-cherry:hid-logitech:hid-logitech-dj:hid-logitech-hidpp:hid-lenovo:hid-microsoft:hid_multitouch:jbd:mbcache:ext3:ext4:isofs:fat:nls_cp437:nls_iso8859-1:msdos:vfat:ntfs"}

# Network kernel modules to include for NFS root support:
NETMODS="kernel/drivers/net"

# Network kernel modules to exclude from above list:
NETEXCL="appletalk arcnet bonding can dummy.ko hamradio hippi ifb.ko irda macvlan.ko macvtap.ko pcmcia sb1000.ko team tokenring tun.ko usb veth.ko wan wimax wireless xen-netback.ko"
# -- END: Taken verbatim from make_slackware_live.sh -- #

#
#  -- function definitions --
#

# Clean up in case of failure:
cleanup() {
  # Clean up by unmounting our loopmounts, deleting tempfiles:
  echo "--- Cleaning up the staging area..."
  # During cleanup, do not abort due to non-zero exit code:
  set +e
  sync
  # No longer needed:
  [ -n "${IMGDIR}" ] && ( rm -rf $IMGDIR )
  [ -n "${KERDIR}" ] && ( rm -rf $KERDIR )
  if [ -n "${USBMNT}" ]; then
    if mount |grep -qw ${USBMNT} ; then umount ${USBMNT} ; fi
    rm -rf $USBMNT
  fi
  if [ -n "${EFIMNT}" ]; then
    if mount |grep -qw ${EFIMNT} ; then umount ${EFIMNT} ; fi
    rm -rf $EFIMNT
  fi
  set -e
} # End of cleanup()

trap 'echo "*** $0 FAILED at line $LINENO ***"; cleanup; exit 1' ERR INT TERM

# Show the help text for this script:
showhelp() {
cat <<EOT
#
# Purpose: to update the content of a Slackware Live USB stick.
#
# $(basename $0) accepts the following parameters:
#   -b|--nobackup              Do not try to backup original kernel and modules.
#   -d|--devices               List removable devices on this computer.
#   -h|--help                  This help.
#   -i|--init <filename>       Replacement init script.
#   -k|--kernel <filename>     The kernel file (or package).
#   -m|--kmoddir <name>        The kernel modules directory (or package).
#   -n|--netsupport            Add network boot support if not yet present.
#   -o|--outdev <filename>     The device name of your USB drive.
#   -p|--persistence           Move persistent data into new Live module.
#   -r|--restore               Restore previous kernel and modules.
#   -s|--scan                  Scan for insertion of new USB device instead of
#                              providing a devicename (using option '-o').
#   -v|--verbose               Show verbose messages.
#   -w|--wait<number>          Add <number> seconds wait time to initialize USB.
#
EOT
} # End of showhelp()

# Scan for insertion of a USB device:
scan_devices() {
  local BD
  # Inotifywatch does not trigger on symlink creation,
  # so we can not watch /sys/block/
  BD=$(inotifywait -q -t ${SCANWAIT} -e create /dev 2>/dev/null |cut -d' ' -f3)
  echo ${BD}
} # End of scan_devices()

# Show a list of removable devices detected on this computer:
show_devices() {
  local MYDATA="${*}"
  if [ -z "${MYDATA}" ]; then
    MYDATA="$(ls --indicator-style=none /sys/block/ |grep -Ev '(ram|loop|dm-)')"
  fi
  echo "# Removable devices detected on this computer:"
  for BD in ${MYDATA} ; do
    if [ $(cat /sys/block/${BD}/removable) -eq 1 ]; then
      echo "# /dev/${BD} : $(cat /sys/block/${BD}/device/vendor) $(cat /sys/block/${BD}/device/model): $(( $(cat /sys/block/${BD}/size) / 2048)) MB"
    fi
  done
  echo "#"
} # End of show_devices()

# Uncompress the initrd based on the compression algorithm used:
uncompressfs () {
  if $(file "${1}" | grep -qi ": gzip"); then
    gzip -cd "${1}"
  elif $(file "${1}" | grep -qi ": XZ"); then
    xz -cd "${1}"
  fi
} # End of uncompressfs ()

# Collect the kernel modules we need for the liveslak initrd.
# When calling this function, the old module tree must already
# have been renamed to ${OLDKVER}.prev
collect_kmods() {
  local IMGDIR="$1"

  # Borrow (and mangle) code from Slackware's mkinitrd
  # to convert the KMODS variable into a collection of modules:
  # Sanitize the modules list first, before any further processing.
  # The awk command eliminates doubles without changing the order:
  KMODS=$(echo $KMODS |tr -s ':' '\n' |awk '!x[$0]++' |tr '\n' ':')
  KMODS=$(echo ${KMODS%:}) # Weed out a trailing ':'

  # Count number of modules
  # This INDEX number gives us an easy way to find individual
  # modules and their arguments, as well as tells us how many
  # times to run through the list
  if ! echo $KMODS | grep ':' > /dev/null ; then  # only 1 module specified
    INDEX=1
  else
    # Trim excess ':' which will screw this routine:
    KMODS=$(echo $KMODS | tr -s ':')
    INDEX=1
    while [ ! "$(echo "$KMODS" | cut -f $INDEX -d ':' )" = "" ]; do
      INDEX=$(expr $INDEX + 1)
    done
    INDEX=$(expr $INDEX - 1)      # Don't include the null value
  fi

  mkdir -p $IMGDIR/lib/modules/${KVER}

  # Wrap everything in a while loop
  i=0
  while [ $i -ne $INDEX ]; do
    i=$(( $i + 1 ))
  
    # FULL_MOD is the module plus any arguments (if any)
    # MODULE is the module name
    # ARGS is any optional arguments to be passed to the kernel
    FULL_MOD="$(echo "$KMODS" | cut -d ':' -f $i)"
    MODULE="$(echo "$FULL_MOD" | cut -d ' ' -f 1 )"
    # Test for arguments
    if echo "$FULL_MOD" | grep ' ' > /dev/null; then
      ARGS=" $(echo "$FULL_MOD" | cut -d ' ' -f 2- )"
    else
      unset ARGS
    fi

    # Get MODULE deps and prepare modprobe lines
    modprobe --dirname ${KMODDIR%%/lib/modules/${KVER}} --set-version $KVER --show-depends --ignore-install $MODULE 2>/dev/null \
      | grep "^insmod " | cut -f 2 -d ' ' | while read SRCMOD; do

      if ! grep -Eq " $(basename $SRCMOD .ko)(\.| |$)" $IMGDIR/load_kernel_modules 2>/dev/null ; then
        LINE="$(echo "modprobe -v $(basename ${SRCMOD%%.gz} .ko)" )"

        # Test to see if arguments should be passed
        # Over-ride the previously defined LINE variable if so
        if [ "$(basename $SRCMOD .ko)" = "$MODULE" ]; then
          # SRCMOD and MODULE are same, ARGS can be passed
          LINE="$LINE$ARGS"
        fi

      fi

      if ! grep -qx "$LINE" $IMGDIR/load_kernel_modules ; then
        echo "$LINE" >> $IMGDIR/load_kernel_modules
      fi

      # Try to add the module to the initrd-tree.  This should be done
      # even if it exists there already as we may have changed compilers
      # or otherwise caused the modules in the initrd-tree to need
      # replacement.
      cd ${KMODDIR}
        # Need to strip ${KMODDIR} from the start of ${SRCMOD}:
        cp -a --parents  $(echo $SRCMOD |sed 's|'${KMODDIR}'/|./|' ) $IMGDIR/lib/modules/${KVER}/ 2>/dev/null
        COPYSTAT=$?
      cd - 1>/dev/null
      if [ $COPYSTAT -eq 0 ]; then
        if [ $VERBOSE -eq 1 ]; then
          echo "OK: $SRCMOD added."
        fi
        # If a module needs firmware, copy that too
        modinfo -F firmware "$SRCMOD" | sed 's/^/\/lib\/firmware\//' |
        while read SRCFW; do
          if cp -a --parents "$SRCFW" $IMGDIR 2>/dev/null; then
            if [ $VERBOSE -eq 1 ]; then
              echo "OK: $SRCFW added."
            fi
          else
            echo "*** WARNING:  Could not find firmware \"$SRCFW\""
          fi
        done
      else
        echo "*** WARNING:  Could not find module \"$SRCMOD\""
      fi
      unset COPYSTAT

    done
  done
  # End of Slackware mkinitrd code.

  # Do we have to add network support?
  if [ $NETSUPPORT -eq 1 ]; then
    # The initrd already contains dhcpcd so we just need to add kmods:
    cd ${KMODDIR}
      mkdir -p ${IMGDIR}/lib/modules/${KVER}
      cp -a --parents ${NETMODS} ${IMGDIR}/lib/modules/${KVER}/
    cd - 1>/dev/null
    # Prune the ones we do not need:
    for KNETRM in ${NETEXCL} ; do
      find ${IMGDIR}/lib/modules/${KVER}/${NETMODS} \
        -name $KNETRM -depth -exec rm -rf {} \;
    done
    # Add any dependency modules:
    for MODULE in $(find ${IMGDIR}/lib/modules/${KVER}/${NETMODS} -type f -exec basename {} .ko \;) ; do
      modprobe --dirname ${KMODDIR%%/lib/modules/${KVER}} --set-version $KVER --show-depends --ignore-install $MODULE 2>/dev/null |grep "^insmod " |cut -f 2 -d ' ' |while read SRCMOD; do
        if [ "$(basename $SRCMOD .ko)" != "$MODULE" ]; then
          cd ${KMODDIR}
            # Need to strip ${KMODDIR} from the start of ${SRCMOD}:
            cp -a --parents $(echo $SRCMOD |sed 's|'${KMODDIR}'/|./|' ) \
              ${IMGDIR}/lib/modules/${KVER}/
          cd - 1>/dev/null
        fi
      done
    done
  fi
  # We added extra modules to the initrd, so we run depmod again:
  if [ $VERBOSE -eq 1 ]; then
    chroot ${IMGDIR} depmod $KVER
  else
    chroot ${IMGDIR} depmod $KVER 2>/dev/null
  fi
}

# Read configuration data from old initrd:
read_initrd() {
  local IMGDIR="$1"

  cd ${IMGDIR}

  # Retrieve the currently defined USB wait time:
  OLDWAIT=$(cat ./wait-for-root)

  # Read the values of liveslak template variables in the init script:
  for TEMPLATEVAR in DISTRO LIVE_HOSTNAME LIVEMAIN LIVEUID MARKER MEDIALABEL PERSISTENCE VERSION ; do
    eval $(grep "^ *${TEMPLATEVAR}=" ./init |head -1)
  done

  if [ $RESTORE -eq 1 ]; then
    # Add '||true' because grep's exit code '1' may abort the script:
    PREVMODDIR=$(find ./lib/modules -type d -mindepth 1 -maxdepth 1 |grep .prev || true)
    if [ -n "${PREVMODDIR}" ] ; then
      KRESTORE=1
    else
      echo "--- No backed-up kernel modules detected in '${IMGFILE}'."
      KRESTORE=0
    fi
  fi
  if [ $UPKERNEL -eq 1 ]; then
    OLDMODDIR=$(find ./lib/modules -type d -mindepth 1 -maxdepth 1 |grep -v .prev)
    if [ $(echo ${OLDMODDIR} |wc -w) -gt 1 ] ; then
      echo "*** Multiple kernelmodule trees detected in '${IMGFILE}'."
      SUPPORTED=0
    else
      OLDKVER=$(basename "${OLDMODDIR}")
      OLDKMODDIRSIZE=$(du -sm "${OLDMODDIR}" |tr '\t' ' ' |cut -d' ' -f1)
      # Find out if the old kernel contains network support.
      # Use presence of 'devlink.ko' in the old tree to determine this,
      # but allow for a pre-set override value based on commandline preference:
      if [ -f ${OLDMODDIR}/kernel/net/core/devlink.ko ]; then
        NETSUPPORT=${NETSUPPORT:-1}
      else
        NETSUPPORT=${NETSUPPORT:-0}
      fi
    fi
  fi
} # End read_initrd()

# Extract the initrd:
extract_initrd() {
  local IMGFILE="$1"

  cd ${IMGDIR}
    uncompressfs ${IMGFILE} \
      | cpio -i -d -H newc --no-absolute-filenames
} # End of extract_initrd()
    
# Modify the extracted initrd and re-pack it:
update_initrd() {
  local IMGFILE="$1"
  local NEED_RECOMP=0

  cd ${IMGDIR}
    if [ ${WAIT} -ge 0 ]; then
      if [ $WAIT != $OLDWAIT ]; then
        echo "--- Updating 'waitforroot' time from '$OLDWAIT' to '$WAIT'"
        echo ${WAIT} > wait-for-root
        NEED_RECOMP=1
      fi
    fi

    if [ $UPKERNEL -eq 1 ]; then
      OLDMODDIR=$(find ./lib/modules -type d -mindepth 1 -maxdepth 1 |grep -v .prev)
      rm -rf ./lib/modules/*.prev
      if [ $KBACKUP -eq 1 ]; then
        # We make one backup:
        if [ $VERBOSE -eq 1 ]; then
          echo "--- Making backup of kernel modules"
        fi
        mv -i ${OLDMODDIR} ${OLDMODDIR}.prev
      else
        echo "--- No room for backing up old kernel modules"
        rm -rf ${OLDMODDIR}
      fi
      # Add modules for the new kernel:
      echo "--- Adding new kernel modules"
      collect_kmods ${IMGDIR}
      NEED_RECOMP=1
    elif [ $RESTORE -eq 1 -a $KRESTORE -eq 1 ]; then
      # Restore previous kernel module tree.
      # The 'read_initrd' routine will already have checked that we have
      # one active and one .prev modules tree:
      OLDMODDIR=$(find ./lib/modules -type d -mindepth 1 -maxdepth 1 |grep .prev || true)
      NEWMODDIR=$(find ./lib/modules -type d -mindepth 1 -maxdepth 1 |grep -v .prev)
      echo "--- Restoring old kernel modules"
      rm -rf ${NEWMODDIR}
      mv ${OLDMODDIR} ${OLDMODDIR%.prev}
      NEED_RECOMP=1
    fi

    if [ -n "${LIVEINIT}" ]; then
      echo "--- Replacing live init script"
      cp ./init ./init.prev
      if grep -q "@LIVEMAIN@" ${LIVEINIT} ; then
        # The provided init is a liveinit template, and we need
        # to substitute the placeholders with actual values:
        parse_template ${LIVEINIT} $(pwd)/init
      else
        cat ${LIVEINIT} > ./init
      fi
      NEED_RECOMP=1
    fi

    if [ ${NEED_RECOMP} -eq 1 ]; then
      echo "--- Compressing the initrd image again"
      chmod 0755 ${IMGDIR}
      find . |cpio -o -H newc |$COMPR > ${IMGFILE}
    fi
  cd - 1>/dev/null  # End of 'cd ${IMGDIR}'
} # End of update_initrd()

# Accept either a kernelimage or a packagename,
# and return the path to a kernelimage:
getpath_kernelimg () {
  local MYDATA="${*}"
  [ -z "${MYDATA}" ] && echo ""

  if [ -n "$(file \"${MYDATA}\" |grep -E 'x86 boot (executable|sector)')" ]; then
    # We have a kernel image:
    echo "${MYDATA}"
  else
    # We assume a Slackware package:
    # Extract the generic kernel from the package and return its filename:
    tar --wildcards -C ${KERDIR} -xf ${MYDATA} boot/vmlinuz-generic-*
    echo "$(ls --indicator-style=none ${KERDIR}/boot/vmlinuz-generic-*)"
  fi
} # End of getpath_kernelimg

# Accept either a directory containing module tree, or a packagename,
# and return the path to a module tree:
getpath_kernelmods () {
  local MYDATA="${*}"
  [ -z "${MYDATA}" ] && echo ""

  if [ -d "${MYDATA}" ]; then
    # We have directory, assume it contains the  kernel modules:
    echo "${MYDATA}"
  else
    # We assume a Slackware package:
    # Extract the kernel modules from the package and return the path:
    tar -C ${KERDIR} -xf ${MYDATA} lib/modules
    cd ${KERDIR}/lib/modules/*
    pwd
  fi
} # End of getpath_kernelmods

# Determine size of a mounted partition (in MB):
get_part_mb_size() {
  local MYSIZE
  MYSIZE=$(df -P -BM ${1} |tail -1 |tr -s '\t' ' ' |cut -d' ' -f2)
  echo "${MYSIZE%M}"
} # End of get_part_mb_size

# Determine free space of a mounted partition (in MB):
get_part_mb_free() {
  local MYSIZE
  MYSIZE=$(df -P -BM ${1} |tail -1 |tr -s '\t' ' ' |cut -d' ' -f4)
  echo "${MYSIZE%M}"
} # End of get_part_mb_free

parse_template() {
  # Parse a liveslak template file and substitute the placeholders.
  local INFILE="$1"
  local OUTFILE="$2"

  # We expect these variables to be set before calling this function.
  # But, we do provide default values.
  DISTRO=${DISTRO:-slackware}
  VERSION=${VERSION:-1337}

  cat ${INFILE} | sed \
    -e "s/@LIVEMAIN@/${LIVEMAIN:-liveslak}/g" \
    -e "s/@MARKER@/${MARKER:-LIVESLAK}/g" \
    -e "s/@MEDIALABEL@/${MEDIALABEL:-LIVESLAK}/g" \
    -e "s/@PERSISTENCE@/${PERSISTENCE:-persistence}/g" \
    -e "s/@DARKSTAR@/${LIVE_HOSTNAME:-darkstar}/g" \
    -e "s/@LIVEUID@/${LIVEUID:-live}/g" \
    -e "s/@DISTRO@/$DISTRO/g" \
    -e "s/@CDISTRO@/${DISTRO^}/g" \
    -e "s/@UDISTRO@/${DISTRO^^}/g" \
    -e "s/@VERSION@/${VERSION}/g" \
    > ${OUTFILE}
} # End of parse_template()

#
#  -- end of function definitions --
#

# ===========================================================================

# Parse the commandline parameters:
if [ -z "$1" ]; then
  showhelp
  exit 1
fi
while [ ! -z "$1" ]; do
  case $1 in
    -b|--nobackup)
      KBACKUP=0
      shift
      ;;
    -d|--devices)
      show_devices
      exit
      ;;
    -h|--help)
      showhelp
      exit
      ;;
    -i|--init)
      LIVEINIT="$(cd $(dirname $2); pwd)/$(basename $2)"
      shift 2
      ;;
    -k|--kernel)
      KERNEL="$2"
      shift 2
      ;;
    -m|--kmoddir)
      KMODDIR="$2"
      shift 2
      ;;
    -n|--netsupport)
      NETSUPPORT=1
      shift
      ;;
    -o|--outdev)
      TARGET="$2"
      shift 2
      ;;
    -p|--persistence)
      CHANGES2SXZ=1
      shift
      ;;
    -r|--restore)
      RESTORE=1
      shift
      ;;
    -s|--scan)
      SCAN=1
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -w|--wait)
      WAIT="$2"
      shift 2
      ;;
    *)
      echo "*** Unknown parameter '$1'!"
      exit 1
      ;;
  esac
done

# Before we start:
if [ "$(id -u)" != "0" ]; then
  echo "*** You need to be root to run $(basename $0)."
  exit 1
fi

#
# More sanity checks:
#

# Either provide a block device, or else scan for a block device:
if [ -z "$TARGET" ]; then
  if [ $SCAN -eq 1 ]; then
    echo "-- Waiting ${SCANWAIT} seconds for a USB stick to be inserted..."
    TARGET=$(scan_devices)
    if [ -z "$TARGET" ]; then
      echo "*** No new USB device detected during $SCANWAIT seconds scan."
      exit 1
    else
      TARGET="/dev/${TARGET}"
    fi
  else
    echo "*** You must specify the Live USB devicename (option '-o')!"
    exit 1
  fi
elif [ $SCAN -eq 1 ]; then
  echo "*** You can not use options '-o' and '-s' at the same time!"
  exit 1
fi

if [ ! -b $TARGET ]; then
  echo "*** Not a block device: '$TARGET' !"
  show_devices
  exit 1
elif [ "$(echo ${TARGET%%[0-9]*})" != "$TARGET" ]; then
  echo "*** You need to point to the USB device, not a partition ($TARGET)!"
  show_devices
  exit 1
fi

if [ -z "$KERNEL" -a -z "$KMODDIR" ]; then
  # We don't need to update the kernel/modules:
  UPKERNEL=0
else
  if [ $RESTORE -eq 1 ]; then
    echo "*** You can not use options '-k'/'-m' and '-r' at the same time!"
    exit 1
  fi
  # If we get here, we have one or both '-k' and '-m'.
  # Sanitize the input values of '-k' and '-m':
  if [ -z "$KERDIR" ]; then
    # Create a temporary extraction directory:
    mkdir -p /mnt
    KERDIR=$(mktemp -d -p /mnt -t alienker.XXXXXX)
    if [ ! -d $KERDIR ]; then
      echo "*** Failed to create temporary extraction dir for the kernel!"
      cleanup
      exit 1
    fi
  fi
  KERNEL="$(getpath_kernelimg ${KERNEL})"
  KMODDIR="$(getpath_kernelmods ${KMODDIR})"

  if [ ! -f "${KERNEL}" -o ! -d "${KMODDIR}" ]; then
    echo "*** You need to provide the path to a kernel imagefile (-k),"
    echo "*** as well as the directory containing the kernel modules (-m)!"
    cleanup
    exit 1
  else
    # Determine the new kernel version from a module,
    # rather than from a directory- or filenames:
    KVER=$(strings ${KMODDIR}/kernel/fs/overlayfs/overlay.ko* |grep ^vermagic |cut -d= -f2 |cut -d' ' -f1)
    if [ -z "${KVER}" ]; then
      echo "*** Could not determine kernel version from the module directory"
      echo "*** (querying module kernel/fs/overlayfs/overlay.ko)!"
      cleanup
      exit 1
    fi
    UPKERNEL=1
  fi
fi

if [ -n "${LIVEINIT}" -a ! -f "${LIVEINIT}" ]; then
  echo "*** The replacement init script '${LIVEINIT}' is not a file!'"
  cleanup
  exit 1
fi

if [ $CHANGES2SXZ -eq 1 ]; then
  # We need to create a module, so add squashfs to the required tools:
  REQTOOLS="${REQTOOLS} mksquashfs"
fi

# Are all the required tools present?
PROG_MISSING=""
for PROGN in ${REQTOOLS} ; do
  if ! which $PROGN 1>/dev/null 2>/dev/null ; then
    PROG_MISSING="${PROG_MISSING}--   $PROGN\n"
  fi
done
if [ ! -z "$PROG_MISSING" ] ; then
  echo "-- Required program(s) not found in search path '$PATH'!"
  echo -e ${PROG_MISSING}
  echo "-- Exiting."
  cleanup
  exit 1
fi

# We are refreshing the Live content.
# Confirm refresh:
cat <<EOT
#
# We are going to update the Live OS on this device.
# ---------------------------------------------------------------------------
# Target is - '$TARGET':
# Vendor : $(cat /sys/block/$(basename $TARGET)/device/vendor)
# Model  : $(cat /sys/block/$(basename $TARGET)/device/model)
# Size   : $(( $(cat /sys/block/$(basename $TARGET)/size) / 2048)) MB
# ---------------------------------------------------------------------------
#
# FDISK OUTPUT:
EOT

echo q |gdisk -l $TARGET 2>/dev/null | \
  while read LINE ; do echo "# $LINE" ; done

# If the user just used the scan option (-s) and did not select a task,
# we will exit the script gracefully now:
if [[ $WAIT -lt 0 && $UPKERNEL -ne 1 && $RESTORE -ne 1 && $NETSUPPORT -ne 1 && $LIVEINIT = ""  && $CHANGES2SXZ -ne 1 ]]; then
  cleanup
  exit 0
else
  # We have one or more tasks to execute, allow user to back out:
  cat <<EOT
***                                                       ***
*** If this is the wrong drive, then press CONTROL-C now! ***
***                                                       ***

EOT
  read -p "Or press ENTER to continue: " JUNK
fi

# OK... the user was sure about the drive...
# Create a temporary extraction directory for the initrd:
mkdir -p /mnt
IMGDIR=$(mktemp -d -p /mnt -t alienimg.XXXXXX)
if [ ! -d $IMGDIR ]; then
  echo "*** Failed to create temporary extraction directory for the initrd!"
  cleanup
  exit 1
fi
chmod 711 $IMGDIR

# Create temporary mount point for the USB device:
mkdir -p /mnt
# USB mounts:
USBMNT=$(mktemp -d -p /mnt -t alienusb.XXXXXX)
if [ ! -d $USBMNT ]; then
  echo "*** Failed to create a temporary mount point for the USB device!"
  cleanup
  exit 1
else
  chmod 711 $USBMNT
fi
EFIMNT=$(mktemp -d -p /mnt -t alienefi.XXXXXX)
if [ ! -d $EFIMNT ]; then
  echo "*** Failed to create a temporary mount point for the USB device!"
  cleanup
  exit 1
else
  chmod 711 $EFIMNT
fi

# Mount the Linux partition:
mount -t auto ${TARGET}3 ${USBMNT}

# Mount the EFI partition:
mount -t vfat -o shortname=mixed ${TARGET}2 ${EFIMNT}

# Determine size of the Linux partition (in MB), and the free space:
USBPSIZE=$(get_part_mb_size ${USBMNT})
USBPFREE=$(get_part_mb_free ${USBMNT})

# Determine size of the EFI partition (in MB), and the free space:
EFIPSIZE=$(get_part_mb_size ${EFIMNT})
EFIPFREE=$(get_part_mb_free ${EFIMNT})

# Record the Slackware Live version:
OLDVERSION="$(cat ${USBMNT}/.isoversion 2>/dev/null)"
echo "-- The medium '${TARGET}' contains '${OLDVERSION}'"

# Find out if the USB contains an EFI bootloader and use it:
if [ ! -f ${EFIMNT}/EFI/BOOT/boot*.efi ]; then
  EFIBOOT=0
  echo "-- Note: UEFI boot file 'bootx64.efi' or 'bootia32.efi' not found on ISO."
  echo "-- UEFI boot will not be supported"
else
  EFIBOOT=1
fi

# Record the size of the running kernel:
if  [ -f "${USBMNT}/boot/vmlinuz*" ]; then
  KIMG="$(find ${USBMNT}/boot/ -type f -name \"vmlinuz*\" |grep -v prev)"
else
  # Default liveslak kernelname:
  KIMG="${USBMNT}/boot/generic"
fi
OLDKERNELSIZE=$(du -sm "${KIMG}" |tr '\t' ' ' |cut -d' ' -f1)

# Collect data from the USB initrd:
extract_initrd ${USBMNT}/boot/initrd.img
read_initrd ${IMGDIR}

# The read_initrd routine will set SUPPORTED to '0'
# if it finds a non-standard configuration for kernel & modules:
if [ $KBACKUP -eq 1 ]; then
  if [ $SUPPORTED -ne 1 ]; then
    echo "*** ${TARGET} has an unsupported kernel configuration."
    echo "*** Exiting now."
    cleanup
    exit 1
  else
    # If free space is low, require '-b' to skip make a backup (unsafe).
    if [ $(( $USBPFREE - $OLDKMODDIRSIZE - $OLDKERNELSIZE )) -lt $MINFREE ]; then
      KBACKUP=-1
    fi
    if [ $EFIBOOT -eq 1 -a $(( $EFIPFREE - $OLDKMODDIRSIZE - $OLDKERNELSIZE )) -lt $MINFREE ]; then
      KBACKUP=-1
    fi
    if [ $KBACKUP -eq -1  ]; then
      echo "*** Not enough free space for a backup of old kernel and modules."
      echo "*** If you want to update your kerel anyway (without backup) then"
      echo "*** you have to add the parameter '-b' to the commandline."
      cleanup
      exit 1
    fi
  fi
fi

# Update the initrd with regard to USB wait time, liveinit, kernel:
update_initrd ${USBMNT}/boot/initrd.img

# Take care of the kernel in the Linux partition:
if [ $UPKERNEL -eq 1 ]; then
  if [ $KBACKUP -eq 1 ]; then
    # We always make one backup with the suffix ".prev":
    if [ $VERBOSE -eq 1 ]; then
      echo "-- Backing up ${KIMG} to ${USBMNT}/boot/$(basename \"${KIMG}\").prev"
    fi
    mv "${KIMG}" ${USBMNT}/boot/$(basename "${KIMG}").prev
  else
    rm -rf "${KIMG}"
  fi
  # And we name our new kernel exactly as the old one:
  if [ $VERBOSE -eq 1 ]; then
    echo "-- Copying \"${KERNEL}\" to ${USBMNT}/boot/$(basename \"${KIMG}\")"
  fi
  cp "${KERNEL}" ${USBMNT}/boot/$(basename "${KIMG}")
elif [ $RESTORE -eq 1 -a $KRESTORE -eq 1 ]; then
  if [ $VERBOSE -eq 1 ]; then
    echo "-- Restoring ${USBMNT}/boot/$(basename \"${KIMG}\").prev to ${KIMG}"
  fi
  rm -f "${KIMG}"
  mv ${USBMNT}/boot/$(basename "${KIMG}").prev "${KIMG}"
fi

if [ $EFIBOOT -eq 1 ]; then
  # Refresh the kernel/initrd on the EFI partition:
  if [ $VERBOSE -eq 1 ]; then
    rsync -rlptD  --delete -v ${USBMNT}/boot/* ${EFIMNT}/boot/
  else
    rsync -rlptD  --delete ${USBMNT}/boot/* ${EFIMNT}/boot/
  fi
  sync
fi

if [ $CHANGES2SXZ -eq 1 ]; then
  if [ ! -d /mnt/live/changes ]; then
    echo "*** No directory '/mnt/live/changes' exists!"
    echo "*** This script must be executed when running ${DISTRO^} Live Edition"
  else
    # We need to be able to write to the partition:
    mount -o remount,rw ${USBMNT}
    # Tell init to wipe the original persistence data at next boot:
    touch /mnt/live/changes/.wipe 2>/dev/null || true
    if [ ! -f /mnt/live/changes/.wipe ]; then
      echo "*** Unable to create file '/mnt/live/changes/.wipe'!"
      echo "*** Are you sure you are running ${DISTRO^} Live Edition?"
    else
      # Squash the persistence data into a Live .sxz module:
      LIVE_MOD_SYS=$(dirname $(find ${USBMNT} -name "0099-${DISTRO}_zzzconf*.sxz" |head -1))
      LIVE_MOD_ADD=$(dirname ${LIVE_MOD_SYS})/addons
      MODNAME="0100-${DISTRO}_customchanges-$(date +%Y%m%d%H%M%S).sxz"
      echo "-- Moving current persistence data into addons module '${MODNAME}'"
      mksquashfs /mnt/live/changes ${LIVE_MOD_ADD}/${MODNAME} -noappend -comp xz -b 1M -e .wipe
    fi
  fi
fi

# Unmount/remove stuff:
cleanup

# THE END

