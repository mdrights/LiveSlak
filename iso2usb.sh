#!/bin/bash
# $Id: iso2usb.sh,v 1.6 2015/11/29 15:07:35 root Exp root $
#
# Copyright 2015  Eric Hameleers, Eindhoven, NL
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

# Be careful:
set -e

# Set to '1' if the script should not ask any questions:
UNATTENDED=0

# By default do not show file operations in detail:
VERBOSE=0

# Seconds to add to the initrd as wait-for-root value:
WAIT=5

# Define ahead of time, so that cleanup knows about them:
IMGDIR=""
EFIMNT=""
ISOMNT=""
USBMNT=""

# Clean up in case of failure:
cleanup() {
  # Clean up by unmounting our loopmounts, deleting tempfiles:
  echo "--- Cleaning up the staging area..."
  # During cleanup, do not abort due to non-zero exit code:
  set +e
  sync
  [ -n "${EFIMNT}" ] && ( /sbin/umount -f ${EFIMNT} 2>/dev/null; rmdir $EFIMNT )
  [ -n "${ISOMNT}" ] && ( /sbin/umount -f ${ISOMNT} 2>/dev/null; rmdir $ISOMNT )
  [ -n "${USBMNT}" ] && ( /sbin/umount -f ${USBMNT} 2>/dev/null; rmdir $USBMNT )
  [ -n "${IMGDIR}" ] && ( rm -rf $IMGDIR )
  set -e
}
trap 'echo "*** $0 FAILED at line $LINENO ***"; cleanup; exit 1' ERR INT TERM

showhelp() {
cat <<EOT
#
# Purpose: to transfer the content of Slackware's Live ISO image
#   to a standard USB thumb drive (which will be formatted and wiped!)
#   and thus create a Slackware Live USB media. 
#
# Your USB thumb drive may contain data!
# This data will be *erased* !
#
# $(basename $0) accepts the following parameters:
#   -h|--help                  This help
#   -i|--infile <filename>     Full path to the ISO image file
#   -o|--outdev <filename>     The device name of your USB drive
#   -u|--unattended            Do not ask any questions
#   -v|--verbose               Show verbose messages
#   -w|--wait<number>          Pause boot <number> seconds to initialize USB

#
# Example:
#
# $(basename $0) -i ~/download/slackware64-live-14.2.iso -o /dev/sdX
#
EOT
}

# Parse the commandline parameters:
if [ -z "$1" ]; then
  showhelp
  exit 1
fi
while [ ! -z "$1" ]; do
  case $1 in
    -h|--help)
      showhelp
      exit
      ;;
    -i|--infile)
      SLISO="$(cd $(dirname $2); pwd)/$(basename $2)"
      shift 2
      ;;
    -o|--outdev)
      TARGET="$2"
      shift 2
      ;;
    -u|--unattended)
      UNATTENDED=1
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      RVERBOSE=" -v --progress "
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
[ -x /bin/id ] && CMD_ID="/bin/id" || CMD_ID="/usr/bin/id"
if [ "$($CMD_ID -u)" != "0" ]; then
  echo "*** You need to be root to run $(basename $0)."
  exit 1
fi

# More sanity checks:
if [ -z "$TARGET" -o -z "$SLISO" ]; then
  echo "*** You must specify both the Live ISO filename and the USB devicename!"
  exit 1
fi

if [ ! -f $SLISO ]; then
  echo "*** This is not a useable file: '$SLISO' !"
  exit 1
fi

if [ ! -b $TARGET ]; then
  echo "*** Not a block device: '$TARGET' !"
  exit 1
elif [ "$(echo ${TARGET%[0-9]})" != "$TARGET" ]; then
  echo "*** You need to point to the USB device, not a partition ($TARGET)!"
  exit 1
fi

# Are all the required not-so-common add-on tools present?
PROG_MISSING=""
for PROGN in blkid cpio extlinux fdisk gdisk mkdosfs sgdisk ; do
  if ! PATH="/sbin:$PATH" which $PROGN 1>/dev/null 2>/dev/null ; then
    PROG_MISSING="${PROG_MISSING}--   $PROGN\n"
  fi
done
if [ ! -z "$PROG_MISSING" ] ; then
  echo "-- Required program(s) not found in root's PATH!"
  echo -e ${PROG_MISSING}
  echo "-- Exiting."
  exit 1
fi

# Confirm wipe:
cat <<EOT
#
# We are going to format this device (erase all data) - '$TARGET':
# Vendor : $(cat /sys/block/$(basename $TARGET)/device/vendor)
# Model  : $(cat /sys/block/$(basename $TARGET)/device/model)
# Size   : $(( $(cat /sys/block/$(basename $TARGET)/size) / 2048)) MB
#
# FDISK OUTPUT:
EOT
/sbin/gdisk -l $TARGET 2>/dev/null | while read LINE ; do echo "# $LINE" ; done

if [ $UNATTENDED -eq 0 ]; then
  cat <<EOT

***                                                       ***
*** If this is the wrong drive, then press CONTROL-C now! ***
***                                                       ***

EOT
  read -p "Or press ENTER to continue: " JUNK
  # OK... the user was sure about the drive...
fi

# Get the LABEL used for the ISO:
LIVELABEL=$(/sbin/blkid -s LABEL -o value ${SLISO})

# Use sgdisk to wipe and then setup the USB device:
# - 1 MB BIOS boot partition
# - 200 MB EFI system partition
# - Let Slackware have the rest
# - Make the Linux partition "legacy BIOS bootable"
# The first sgdisk command is allowed to have non-zero exit code:
/sbin/sgdisk -Z $TARGET || true
/sbin/sgdisk -og $TARGET || true
/sbin/sgdisk \
  -n 1:2048:4095 -c 1:"BIOS Boot Partition" -t 1:ef02 \
  -n 2:4096:413695 -c 2:"EFI System Partition" -t 2:ef00 \
  -n 3:413696:0 -c 3:"Slackware Linux" -t 3:8300 \
  $TARGET
/sbin/sgdisk -A 3:set:2 $TARGET
# Show what we did to the USB stick:
/sbin/sgdisk -p -A 3:show $TARGET

# Create filesystems:
# Not enough clusters for a 32 bit FAT:
/sbin/mkdosfs -s 2 -n "DOS" ${TARGET}1
/sbin/mkdosfs -F32 -s 2 -n "EFI" ${TARGET}2
# KDE tends to automount.. so try an umount:
if /sbin/mount |grep -qw ${TARGET}3 ; then /sbin/umount ${TARGET}3 || true ; fi
/sbin/mkfs.ext4 -F -F -L "${LIVELABEL}" -m 0 ${TARGET}3
/sbin/tune2fs -c 0 -i 0 ${TARGET}3

# Create temporary mount points for the ISO file:
mkdir -p /mnt
EFIMNT=$(mktemp -d -p /mnt -t alienefi.XXXXXX)
if [ ! -d $EFIMNT ]; then
  echo "*** Failed to create a temporary mount point for the ISO!"
  exit 1
else
  chmod 711 $EFIMNT
fi
ISOMNT=$(mktemp -d -p /mnt -t alieniso.XXXXXX)
if [ ! -d $ISOMNT ]; then
  echo "*** Failed to create a temporary mount point for the ISO!"
  exit 1
else
  chmod 711 $ISOMNT
fi

# Find out if the ISO contains an EFI bootloader and use it:
EFIOFFSET=$(/sbin/fdisk -lu ${SLISO} 2>/dev/null |grep EFI |tr -s ' ' | cut -d' ' -f 2)
if [ -n "$EFIOFFSET" ]; then
  # Mount the EFI partition so we can retrieve the EFI bootloader:
  /sbin/mount -o loop,offset=$((512*$EFIOFFSET))  ${SLISO} ${EFIMNT}
  if [ ! -f ${EFIMNT}/EFI/BOOT/bootx64.efi ]; then
    echo "-- Note: UEFI boot file 'bootx64.efi' not found on ISO."
    echo "-- UEFI boot will not be supported"
  fi
fi

# Create a temporary mount point for the USB device:
mkdir -p /mnt
USBMNT=$(mktemp -d -p /mnt -t alienusb.XXXXXX)
if [ ! -d $USBMNT ]; then
  echo "*** Failed to create a temporary mount point for the USB device!"
  exit 1
else
  chmod 711 $USBMNT
fi

# Mount the EFI partition and copy the EFI boot image to it:
/sbin/mount -t vfat -o shortname=mixed ${TARGET}2 ${USBMNT}
mkdir -p ${USBMNT}/EFI/BOOT
cp ${EFIMNT}/EFI/BOOT/bootx64.efi ${USBMNT}/EFI/BOOT
/sbin/umount ${USBMNT}
/sbin/umount ${EFIMNT}

# Mount the Linux partition:
/sbin/mount -t auto ${TARGET}3 ${USBMNT}

# Loop-mount the ISO (or 1st partition if this is a hybrid ISO):
/sbin/mount -o loop ${SLISO} ${ISOMNT}

# Copy the ISO content into the USB Linux partition:
echo "--- Copying files from ISO to USB... takes some time."
rsync -a ${RVERBOSE} ${ISOMNT}/* ${USBMNT}/

# Create a temporary extraction directory for the initrd:
mkdir -p /mnt
IMGDIR=$(mktemp -d -p /mnt -t alienimg.XXXXXX)
if [ ! -d $IMGDIR ]; then
  echo "*** Failed to create a temporary extraction directory for the initrd!"
  exit 1
else
  chmod 711 $IMGDIR
fi

# USB boot medium needs a few seconds boot delay or else the overlay will fail:
echo "--- Extracting Slackware initrd and adding rootdelay for USB..."
cd ${IMGDIR}
gunzip -cd ${USBMNT}/boot/initrd.img |cpio -i -d -H newc --no-absolute-filenames
echo ${WAIT} > wait-for-root
echo "--- Compressing the initrd image again:"
chmod 0755 ${IMGDIR}
find . |cpio -o -H newc |gzip > ${USBMNT}/boot/initrd.img
cd - 2>/dev/null

# Create persistence directory:
mkdir -p ${USBMNT}/persistence

# Use extlinux to make the USB device bootable:
echo "--- Making the USB drive '$TARGET' bootable using extlinux..."
mv ${USBMNT}/boot/syslinux ${USBMNT}/boot/extlinux
mv ${USBMNT}/boot/extlinux/isolinux.cfg ${USBMNT}/boot/extlinux/extlinux.conf
rm ${USBMNT}/boot/extlinux/isolinux.*
/sbin/extlinux --install ${USBMNT}/boot/extlinux

# Unmount/remove stuff:
cleanup

# Install a GPT compatible MBR record:
if [ -f /usr/share/syslinux/gptmbr.bin ]; then
  cat /usr/share/syslinux/gptmbr.bin > ${TARGET}
else
  echo "*** Failed to make USB device bootable - 'gptmbr.bin' not found!"
  exit 1 
fi

# THE END

