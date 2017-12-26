#!/bin/sh

# Copyright 2013  Patrick J. Volkerding, Sebeka, Minnesota, USA
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

# 30-nov-2015: Modified by Eric Hameleers for Slackware Live Edition.
# 27-dec-2017: Modified by Eric Hameleers, make it compatible with grub-2.02.

# Create the 64-bit EFI GRUB binary (bootx64.efi) and the El-Torito boot
# image (efiboot.img) that goes in the /isolinux directory for booting on
# UEFI systems.

# Preparations:
eval $1  # EFIFORM=value1
eval $2  # EFISUFF=value2
eval $2  # EFIDIR=value3

# Defaults in case the script was called without parameters:
EFIFORM=${EFIFORM:-"x86_64"}
EFISUFF=${EFISUFF:-"x64"}
EFIDIR=${EFIDIR:-"/EFI/BOOT"}

echo
echo "Building ${EFIDIR}/boot${EFISUFF}.efi and /boot/syslinux/efiboot.img."

# Create a list of modules to be added to the efi file, so that the script
# works with mutiple grub releases (grub-2.02 added the 'disk' module):
GMODDIR="$(dirname $(LANG=C grub-mkimage -O ${EFIFORM}-efi -p ${EFIDIR} alienbob 2>&1 | cut -d\` -f2 |cut -d\' -f1) )"
GMODLIST=""
for GMOD in part_gpt part_msdos fat ext2 iso9660 ntfs chain linux boot configfile normal regexp extcmd minicmd reboot halt search search_fs_file search_fs_uuid search_label gfxterm gfxmenu gfxterm_background fxterm_menu efi_gop efi_uga all_video loadbios gzio echo true probe loadenv bitmap_scale font cat help ls png jpeg tga test at_keyboard usb_keyboard disk memdisk nativedisk file loopback tar ; do
  [ -f ${GMODDIR}/${GMOD}.mod ] && GMODLIST="${GMODLIST} ${GMOD}"
done

# Build bootx64.efi/bootia32.efi, which will be installed here in ${EFIDIR}.
grub-mkimage --format=${EFIFORM}-efi --output=boot${EFISUFF}.efi --config=grub-embedded.cfg --compression=xz --prefix=${EFIDIR} ${GMODLIST}

# Then, create a FAT formatted image that contains bootx64.efi in the
# ${EFIDIR} directory.  This is used to bootstrap GRUB from the ISO image.
dd if=/dev/zero of=efiboot.img bs=1K count=1440
# Format the image as FAT12:
mkdosfs -F 12 efiboot.img
# Create a temporary mount point:
MOUNTPOINT=$(mktemp -d)
# Mount the image there:
mount -o loop efiboot.img $MOUNTPOINT
# Copy the GRUB binary to /EFI/BOOT:
mkdir -p $MOUNTPOINT/${EFIDIR}
cp -a boot${EFISUFF}.efi $MOUNTPOINT/${EFIDIR}
# Unmount and clean up:
umount $MOUNTPOINT
rmdir $MOUNTPOINT
# Move the efiboot.img to ../../boot/syslinux:
mv efiboot.img ../../boot/syslinux/

echo
echo "Done building ${EFIDIR}/boot${EFISUFF}.efi and /boot/syslinux/efiboot.img."

