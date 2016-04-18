#!/bin/bash

# $Id: make_slackware_live.sh,v 1.13 2015/12/04 13:51:41 root Exp root $
# Copyright 2014, 2015, 2016  Eric Hameleers, Eindhoven, NL 
# All rights reserved.
#
#   Permission to use, copy, modify, and distribute this software for
#   any purpose with or without fee is hereby granted, provided that
#   the above copyright notice and this permission notice appear in all
#   copies.
#
#   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.
# -----------------------------------------------------------------------------
#
# This script creates a live image for a Slackware OS.
# Features:
# - boots using isolinux/extlinux on BIOS, or grub on UEFI.
# - requires kernel >= 4.0 which supports multiple lower layers in overlay
# - uses squashfs to create compressed modules out of directory trees
# - uses overlayfs to bind multiple squashfs modules together
# - you can add your own modules into ./addons/ or ./optional subdirectories.
# - persistence is enabled when writing the ISO to USB stick using iso2usb.sh.
# - LUKS encrypted homedirectory is optional on USB stick using iso2usb.sh.
#
# -----------------------------------------------------------------------------

# Version of the Live OS generator:
VERSION="0.7.3"

# Directory where our live tools are stored:
LIVE_TOOLDIR=${LIVE_TOOLDIR:-"$(cd $(dirname $0); pwd)"}

# Load the optional configuration file:
CONFFILE=${LIVE_TOOLDIR}/$(basename $0 .sh).conf
if [ -f ${CONFFILE} ]; then
  echo "-- Loading configuration file."
  . ${CONFFILE}
fi

# Set to "YES" to send error output to the console:
DEBUG=${DEBUG:-"NO"}

# Set to "YES" in order to delete everything we have,
# and rebuild any pre-existing .sxz modules from scratch:
FORCE=${FORCE:-"NO"}

# Set to 32 to be more compatible with the specs. Slackware uses 4 by default:
BOOTLOADSIZE=${BOOTLOADSIZE:-4}

# If you want to include an EFI boot image for 32bit Slackware then you
# need a recompiled grub which supports 32bit EFI (Slackware's grub will not).
# A patch for grub.SlackBuild to enable this feature can be found
# in the source directory. Works for both the 32bit and the 64bit grub package.
# Therefore we disable 32bit EFI by default. Enable at your own peril:
EFI32=${EFI32:-"NO"}

# Include support for NFS root (PXE boot), will increase size of the initrd:
NFSROOTSUP=${NFSROOTSUP:-"YES"}

# Timestamp:
THEDATE=$(date +%Y%m%d)

#
# ---------------------------------------------------------------------------
#

# The root and live user passwords of the image:
ROOTPW=${ROOTPW:-"root"}
LIVEPW=${LIVEPW:-"live"}

# Distribution name:
DISTRO=${DISTRO:-"slackware"}

# Custom name for the host:
LIVE_HOSTNAME=${LIVE_HOSTNAME:-"darkstar"}

# What type of Live image?
# Choices are: SLACKWARE, XFCE, KDE4, PLASMA5, MATE, CINNAMON
LIVEDE=${LIVEDE:-"SLACKWARE"}

# What runlevel to use if adding a DE like: XFCE, KDE4, PLASMA5 etc...
RUNLEVEL=${RUNLEVEL:-4}

# Use the graphical syslinux menu (YES or NO)?
SYSMENU=${SYSMENU:-"YES"}

# This variable can be set to a comma-separated list of package series.
# The squashfs module(s) for these package series will then be re-generated.
# Example commandline parameter: "-r l,kde,kdei"
REFRESH=""

# The amount of seconds we want the init script to wait to give the kernel's
# USB subsystem time to settle. The default value of mkinitrd is "1" which
# is too short for use with USB sticks but "1" is fine for CDROM/DVD.
WAIT=${WAIT:-"5"}

#
# ---------------------------------------------------------------------------
#

# Who built the live image:
BUILDER=${BUILDER:-"Alien BOB"}

# Console font to use with syslinux for better language support:
CONSFONT=${CONSFONT:-"ter-i16v.psf"}

# The ISO main directory:
LIVEMAIN=${LIVEMAIN:-"liveslak"}

# Marker used for finding the Slackware Live files:
MARKER=${MARKER:-"SLACKWARELIVE"}

# The filesystem label we will be giving our ISO:
MEDIALABEL=${MEDIALABEL:-"LIVESLAK"}

# The name of the directory used for storing persistence data:
PERSISTENCE=${PERSISTENCE:-"persistence"}

# Slackware version to use (note: this won't work for Slackware <= 14.1):
SL_VERSION=${SL_VERSION:-"current"}

# Slackware architecture to install:
SL_ARCH=${SL_ARCH:-"x86_64"}

# Root directory of a Slackware local mirror tree;
# You can define custom repository location (must be in local filesystem)
# for any module in the file ./pkglists/<module>.conf:
SL_REPO=${SL_REPO:-"/mnt/auto/sox/ftp/pub/Linux/Slackware"}
DEF_SL_REPO=${SL_REPO}

# List of Slackware package series - each will become a squashfs module:
SEQ_SLACKWARE="tagfile:a,ap,d,e,f,k,kde,kdei,l,n,t,tcl,x,xap,xfce,y pkglist:slackextra"

# Stripped-down Slackware with XFCE as the Desktop Environment:
# - each series will become a squashfs module:
SEQ_XFCEBASE="min,xbase,xapbase,xfcebase"

# Stripped-down Slackware with KDE4 as the Desktop Environment:
# - each series will become a squashfs module:
SEQ_KDE4BASE="pkglist:min,xbase,xapbase,kde4base"

# List of Slackware package series with Plasma5 instead of KDE 4 (full install):
# - each will become a squashfs module:
SEQ_PLASMA5="tagfile:a,ap,d,e,f,k,l,n,t,tcl,x,xap,xfce,y pkglist:slackextra,kde4plasma5,plasma5,alien local:slackpkg+"

# List of Slackware package series with MSB instead of KDE 4 (full install):
# - each will become a squashfs module:
SEQ_MSB="tagfile:a,ap,d,e,f,k,l,n,t,tcl,x,xap,xfce,y pkglist:slackextra,mate local:slackpkg+"

# List of Slackware package series with Cinnamon instead of KDE4 (full install):
# - each will become a squashfs module:
SEQ_CIN="tagfile:a,ap,d,e,f,k,l,n,t,tcl,x,xap,xfce,y pkglist:slackextra,cinnamon local:slackpkg+"

# List of kernel modules required for a live medium to boot properly;
# Lots of HID modules added to support keyboard input for LUKS password entry:
KMODS=${KMODS:-"squashfs:overlay:loop:xhci-pci:ohci-pci:ehci-pci:xhci-hcd:uhci-hcd:ehci-hcd:usb-storage:hid:usbhid:hid-generic:hid-cherry:hid-logitech:hid-logitech-dj:hid-logitech-hidpp:hid-lenovo:hid-microsoft:jbd:mbcache:ext3:ext4:isofs:fat:nls_cp437:nls_iso8859-1:msdos:vfat"}

# Firmware for wired network cards required for NFS root support:
NETFIRMWARE="3com acenic adaptec bnx tigon e100 sun kaweth tr_smctr cxgb3"

# Network kernel modules to include for NFS root support:
NETMODS="kernel/drivers/net"

# Network kernel modules to exclude from above list:
NETEXCL="appletalk arcnet bonding can dummy.ko hamradio hippi ifb.ko irda macvlan.ko macvtap.ko pcmcia sb1000.ko team tokenring tun.ko usb veth.ko wan wimax wireless xen-netback.ko"

#
# ---------------------------------------------------------------------------
#

# What compression to use for the initrd?
# Default is xz with CRC32 (the kernel's XZ decoder does not support CRC64),
# the alternative is gzip (which adds  ~30% to the initrd size).
COMPR=${COMPR:-"xz --check=crc32"}

# What compression to use for the squashfs modules?
# Default is xz, alternatives are gzip, lzma, lzo:
SXZ_COMP=${SXZ_COMP:-"xz"}

# Mount point where Live filesystem is assembled (no storage requirements):
LIVE_ROOTDIR=${LIVE_ROOTDIR:-"/mnt/slackwarelive"}

# Toplevel directory of our staging area (this needs sufficient storage):
LIVE_STAGING=${LIVE_STAGING:-"/tmp/slackwarelive_staging"}

# Work directory where we will create all the temporary stuff:
LIVE_WORK=${LIVE_WORK:-"${LIVE_STAGING}/temp"}

# Directory to be used by overlayfs for data manipulation,
# needs to be a directory in the same filesystem as ${LIVE_WORK}:
LIVE_OVLDIR=${LIVE_OVLDIR:-"${LIVE_WORK}/.ovlwork"}

# Directory where we will move the kernel and create the initrd;
# note that a ./boot directory will be created in here by installpkg:
LIVE_BOOT=${LIVE_BOOT:-"${LIVE_STAGING}/${LIVEMAIN}/bootinst"}

# Directories where the squashfs modules will be created:
LIVE_MOD_SYS=${LIVE_MOD_SYS:-"${LIVE_STAGING}/${LIVEMAIN}/system"}
LIVE_MOD_ADD=${LIVE_MOD_ADD:-"${LIVE_STAGING}/${LIVEMAIN}/addons"}
LIVE_MOD_OPT=${LIVE_MOD_OPT:-"${LIVE_STAGING}/${LIVEMAIN}/optional"}

# Directory where the live ISO image will be written:
OUTPUT=${OUTPUT:-"/tmp"}

# ---------------------------------------------------------------------------
# Define some functions.
# ---------------------------------------------------------------------------

# Clean up in case of failure:
cleanup() {
  # Clean up by unmounting our loopmounts, deleting tempfiles:
  echo "--- Cleaning up the staging area..."
  sync
  umount ${LIVE_ROOTDIR}/sys 2>${DBGOUT} || true
  umount ${LIVE_ROOTDIR}/proc 2>${DBGOUT} || true
  umount ${LIVE_ROOTDIR}/dev 2>${DBGOUT} || true
  umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
  # Need to umount the squashfs modules too:
  umount ${LIVE_WORK}/*_$$ 2>${DBGOUT} || true

  rmdir ${LIVE_ROOTDIR} 2>${DBGOUT}
  rmdir ${LIVE_WORK}/*_$$ 2>${DBGOUT}
  rm ${LIVE_MOD_OPT}/* 2>${DBGOUT} || true
  rm ${LIVE_MOD_ADD}/* 2>${DBGOUT} || true
}
trap 'echo "*** $0 FAILED at line $LINENO ***"; cleanup; exit 1' ERR INT TERM

# Uncompress the initrd based on the compression algorithm used:
uncompressfs () {
  if $(file "${1}" | grep -qi ": gzip"); then
    gzip -cd "${1}"
  elif $(file "${1}" | grep -qi ": XZ"); then
    xz -cd "${1}"
  fi
}

#
# Return the full pathname of first package found below $2 matching exactly $1:
#
full_pkgname() {
  PACK=$1
  TOPDIR=$2
  # Perhaps I will use this more readable code in future:
  #for FL in $(find ${TOPDIR} -name "${PACK}-*.t?z" 2>/dev/null) ; do
  #  # Weed out package names starting with "$PACK"; we want exactly "$PACK":
  #  if [ "$(echo $FL |rev |cut -d- -f4- |cut -d/ -f1 |rev)" != "$PACK" ]; then
  #    continue
  #  else
  #    break
  #  fi
  #done
  #echo "$FL"
  echo "$(find ${TOPDIR} -name "${PACK}-*.t?z" 2>/dev/null |grep -E "\<${PACK//+/\\+}-[^-]+-[^-]+-[^-]+.t?z" |head -1)"
}

#
# Find packages and install them into the temporary root:
#
function install_pkgs() {
  if [ -z "$1" ]; then
    echo "-- function install_pkgs: Missing module name."
    exit 1
  fi
  if [ ! -d "$2" ]; then
    echo "-- function install_pkgs: Target directory '$2' does not exist!"
    exit 1
  elif [ ! -f "$2/${MARKER}" ]; then
    echo "-- function install_pkgs: Target '$2' does not contain '${MARKER}' file."
    echo "-- Did you choose the right installation directory?"
    exit 1
  fi

  # Define the default Slackware repository, can be overridden here:
  SL_REPO="${DEF_SL_REPO}"
  SL_PKGROOT="${DEF_SL_PKGROOT}"
  SL_PATCHROOT="${DEF_SL_PATCHROOT}"

  if [ "$3" = "local" -a -d ${LIVE_TOOLDIR}/local${DIRSUFFIX}/$1 ]; then
    echo "-- Installing local packages from subdir 'local${DIRSUFFIX}/$1'."
    installpkg --terse --root "$2" "local${DIRSUFFIX}/$1/*.t?z"
  else
    # Load package list and (optional) custom repo info:
    if [ "$3" = "tagfile" ]; then
      PKGCONF="__tagfile__"
      PKGFILE=${SL_PKGROOT}/${1}/tagfile
    else
      PKGCONF=${LIVE_TOOLDIR}/pkglists/$(echo $1 |tr [A-Z] [a-z]).conf
      PKGFILE=${LIVE_TOOLDIR}/pkglists/$(echo $1 |tr [A-Z] [a-z]).lst
    fi

    if [ -f ${PKGCONF} ]; then
      echo "-- Loading repo info for '$1'."
      . ${PKGCONF}
    fi

    if [ -f ${PKGFILE} ]; then
      echo "-- Loading package list '$PKGFILE'."
    else
      echo "-- Mandatory package list file '$PKGFILE' is missing! Exiting."
      exit 1
    fi

    if [ "${SL_REPO}" = "${DEF_SL_REPO}" ]; then
      # We require that the Slackware package mirror is available:
      true
    elif [ ! -d ${SL_REPO} -o -z "$(find ${SL_PKGROOT} -type f 2>/dev/null)" ]; then
      # Oops... empty local repository. Let's see if we can rsync from remote:
      echo "** Slackware package repository root '${SL_REPO}' does not exist or is empty!"
      RRES=1
      if [ -n "${SL_REPO_URL}" ]; then
        mkdir -p ${SL_REPO}
        # Must be a rsync URL!
        echo "-- Rsync-ing repository content from '${SL_REPO_URL}' to local directory '${SL_REPO}'..."
        echo "-- This can be time-consuming.  Please wait."
        rsync -rlptD --no-motd ${SL_REPO_URL}/ ${SL_REPO}/
        RRES=$?
        echo "-- Done rsync-ing from '${SL_REPO_URL}'."
      fi
      if [ $RRES -ne 0 ]; then
        echo "** Exiting."
        exit 1
      fi
    fi

    for PKG in $(cat ${PKGFILE} |grep -v -E '^ *#|^$' |cut -d: -f1); do
      # Look in ./patches ; then ./${DISTRO}$DIRSUFFIX ; then ./extra
      # Need to escape any '+' in package names such a 'gtk+2':
      if [ ! -z "${SL_PATCHROOT}" ]; then
        FULLPKG=$(full_pkgname ${PKG} ${SL_PATCHROOT})
      else
        FULLPKG=""
      fi
      if [ "x${FULLPKG}" = "x" ]; then
        FULLPKG=$(full_pkgname ${PKG} ${SL_PKGROOT})
      else
        echo "-- $PKG found in patches"
      fi
      if [ "x${FULLPKG}" = "x" ]; then
        # One last attempt: look in ./extra
        FULLPKG=$(full_pkgname ${PKG} $(dirname ${SL_PKGROOT})/extra)
      fi

      if [ "x${FULLPKG}" = "x" ]; then
        echo "-- Package $PKG was not found in $(dirname ${SL_REPO}) !"
      else
        # Determine if we need to install or upgrade a package:
        for INSTPKG in $(ls -1 "$2"/var/log/packages/${PKG}-* 2>/dev/null |rev |cut -d/ -f1 |cut -d- -f4- |rev) ; do
          if [ "$INSTPKG" = "$PKG" ]; then
            break
          fi
        done
        if [ "$INSTPKG" = "$PKG" ]; then
          ROOT="$2" upgradepkg --reinstall "${FULLPKG}"
        else
          installpkg --terse --root "$2" "${FULLPKG}"
        fi
      fi
    done
  fi

  if [ "$TRIM" = "doc" -o "$TRIM" = "mandoc" -o "$LIVEDE" = "XFCE"  ]; then
    # Remove undesired (too big for a live OS) document subdirectories:
    (cd "${2}/usr/doc" && find . -type d -mindepth 2 -maxdepth 2 -exec rm -rf {} \;)
  fi
  if [ "$TRIM" = "mandoc" ]; then
    # Also remove man pages:
    rm -rf "$2"/usr/man
  fi

  # End install_pkgs
}


#
# Create the graphical multi-language syslinux boot menu:
#
function gen_bootmenu() {

  MENUROOTDIR="$1/menu"

  # Generate vesamenu structure - many files because of the selection tree.
  mkdir -p ${MENUROOTDIR}

  # Initialize an empty keyboard selection and language menu:
  rm -f ${MENUROOTDIR}/kbd.cfg
  rm -f ${MENUROOTDIR}/lang*.cfg

  # Generate main (US) vesamenu.cfg:
  cat ${LIVE_TOOLDIR}/menu.tpl | sed \
    -e "s/@KBD@/us/g" \
    -e "s/@LANG@/us/g" \
    -e "s/@CONSFONT@/$CONSFONT/g" \
    -e "s/@DIRSUFFIX@/$DIRSUFFIX/g" \
    -e "s/@DISTRO@/$DISTRO/g" \
    -e "s/@CDISTRO@/${DISTRO^}/g" \
    -e "s/@UDISTRO@/${DISTRO^^}/g" \
    -e "s/@KVER@/$KVER/g" \
    -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
    -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
    -e "s/@LIVEDE@/$(echo $LIVEDE |sed 's/BASE//')/g" \
    -e "s/@SL_VERSION@/$SL_VERSION/g" \
    -e "s/@VERSION@/$VERSION/g" \
    > ${MENUROOTDIR}/vesamenu.cfg

  for LANCOD in $(cat ${LIVE_TOOLDIR}/languages |grep -Ev "(^ *#|^$)" |cut -d: -f1)
  do
    LANDSC=$(cat ${LIVE_TOOLDIR}/languages |grep "^$LANCOD:" |cut -d: -f2)
    KBD=$(cat ${LIVE_TOOLDIR}/languages |grep "^$LANCOD:" |cut -d: -f3)
    # First, create keytab files if they are missing:
    if [ ! -f ${MENUROOTDIR}/${KBD}.ktl ]; then
      keytab-lilo $(find /usr/share/kbd/keymaps/i386 -name "us.map.gz") $(find /usr/share/kbd/keymaps/i386 -name "${KBD}.map.gz") > ${MENUROOTDIR}/${KBD}.ktl
    fi
    # Add this keyboard to the keyboard selection menu:
    cat <<EOL >> ${MENUROOTDIR}/kbd.cfg
label ${LANCOD}
  menu label ${LANDSC}
  kbdmap menu/${KBD}.ktl
  kernel vesamenu.c32
  append menu/menu_${LANCOD}.cfg

EOL

    # Generate custom vesamenu.cfg for selected keyboard:
    cat ${LIVE_TOOLDIR}/menu.tpl | sed \
      -e "s/@KBD@/$KBD/g" \
      -e "s/@LANG@/$LANCOD/g" \
      -e "s/@CONSFONT@/$CONSFONT/g" \
      -e "s/@DIRSUFFIX@/$DIRSUFFIX/g" \
      -e "s/@DISTRO@/$DISTRO/g" \
      -e "s/@CDISTRO@/${DISTRO^}/g" \
      -e "s/@UDISTRO@/${DISTRO^^}/g" \
      -e "s/@KVER@/$KVER/g" \
      -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
      -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
      -e "s/@LIVEDE@/$(echo $LIVEDE |sed 's/BASE//')/g" \
      -e "s/@SL_VERSION@/$SL_VERSION/g" \
      -e "s/@VERSION@/$VERSION/g" \
      > ${MENUROOTDIR}/menu_${LANCOD}.cfg

    # Generate custom language selection submenu for selected keyboard:
    for SUBCOD in $(cat ${LIVE_TOOLDIR}/languages |grep -Ev "(^ *#|^$)" |cut -d: -f1) ; do
      SUBKBD=$(cat ${LIVE_TOOLDIR}/languages |grep "^$SUBCOD:" |cut -d: -f3)
      cat <<EOL >> ${MENUROOTDIR}/lang_${LANCOD}.cfg
label $(cat ${LIVE_TOOLDIR}/languages |grep "^$SUBCOD:" |cut -d: -f1)
  menu label $(cat ${LIVE_TOOLDIR}/languages |grep "^$SUBCOD:" |cut -d: -f2)
EOL
      if [ "$SUBKBD" = "$KBD" ]; then
        echo "  menu default" >> ${MENUROOTDIR}/lang_${LANCOD}.cfg
      fi
      cat <<EOL >> ${MENUROOTDIR}/lang_${LANCOD}.cfg
  kernel /boot/generic
  append initrd=/boot/initrd.img load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=$KBD tz=$(cat ${LIVE_TOOLDIR}/languages |grep "^$SUBCOD:" |cut -d: -f4) locale=$(cat ${LIVE_TOOLDIR}/languages |grep "^$SUBCOD:" |cut -d: -f5) xkb=$(cat ${LIVE_TOOLDIR}/languages |grep "^$SUBCOD:" |cut -d: -f6)

EOL
    done

  done
}

#
# Create the grub menu file for UEFI boot:
#
function gen_uefimenu() {

  GRUBDIR="$1"

  # Generate the grub menu structure - many files because of the selection tree.
  # I expect the directory to exist... but you never know.
  mkdir -p ${GRUBDIR}

  # Initialize an empty keyboard, language and timezone selection menu:
  rm -f ${GRUBDIR}/kbd.cfg
  rm -f ${GRUBDIR}/lang.cfg
  rm -f ${GRUBDIR}/tz.cfg

  # Generate main grub.cfg:
  cat ${LIVE_TOOLDIR}/grub.tpl | sed \
    -e "s/@KBD@/us/g" \
    -e "s/@LANG@/us/g" \
    -e "s/@CONSFONT@/$CONSFONT/g" \
    -e "s/@DIRSUFFIX@/$DIRSUFFIX/g" \
    -e "s/@DISTRO@/$DISTRO/g" \
    -e "s/@CDISTRO@/${DISTRO^}/g" \
    -e "s/@UDISTRO@/${DISTRO^^}/g" \
    -e "s/@KVER@/$KVER/g" \
    -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
    -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
    -e "s/@LIVEDE@/$(echo $LIVEDE |sed 's/BASE//')/g" \
    -e "s/@SL_VERSION@/$SL_VERSION/g" \
    -e "s/@VERSION@/$VERSION/g" \
    > ${GRUBDIR}/grub.cfg

  # Set a default keyboard selection:
  cat <<EOL > ${GRUBDIR}/kbd.cfg
# Keyboard selection:
set default = $sl_lang

EOL

  # Set a default language selection:
  cat <<EOL > ${GRUBDIR}/lang.cfg
# Language selection:
set default = $sl_lang

EOL

  # Create the remainder of the selection menus:
  for LANCOD in $(cat languages |grep -Ev "(^ *#|^$)" |cut -d: -f1) ; do
    LANDSC=$(cat languages |grep "^$LANCOD:" |cut -d: -f2)
    KBD=$(cat languages |grep "^$LANCOD:" |cut -d: -f3)
    XKB=$(cat languages |grep "^$LANCOD:" |cut -d: -f6)
    LANLOC=$(cat languages |grep "^$LANCOD:" |cut -d: -f5)
    # Add this entry to the keyboard selection menu:
    cat <<EOL >> ${GRUBDIR}/kbd.cfg
menuentry "${LANDSC}" {
  set sl_kbd="$KBD"
  set sl_xkb="$XKB"
  set sl_lang="$LANDSC"
  export sl_kbd
  export sl_xkb
  export sl_lang
  configfile \$grubdir/grub.cfg
}

EOL

    # Add this entry to the language selection menu:
    cat <<EOL >> ${GRUBDIR}/lang.cfg
menuentry "${LANDSC}" {
  set sl_locale="$LANLOC"
  set sl_lang="$LANDSC"
  export sl_locale
  export sl_lang
  configfile \$grubdir/grub.cfg
}

EOL

  done

  # Create the timezone selection menu:
  TZDIR="/usr/share/zoneinfo"
  TZLIST=$(mktemp -t alientz.XXXXXX)
  if [ ! -f $TZLIST ]; then
    echo "*** Failed to create a temporary file!"
    exit 1
  fi
  # First, create a list of timezones:
  # This code taken from Slackware script:
  # source/a/glibc-zoneinfo/timezone-scripts/output-updated-timeconfig.sh
  # Author: Patrick Volkerding <volkerdi@slackware.com>
  # US/ first:
  ( cd $TZDIR
    find . -type f | xargs file | grep "timezone data" | cut -f 1 -d : | cut -f 2- -d / | sort | grep "^US/" | while read zone ; do
      echo "${zone}" >> $TZLIST
    done
  )
  # Don't list right/ and posix/ zones:
  ( cd $TZDIR
    find . -type f | xargs file | grep "timezone data" | cut -f 1 -d : | cut -f 2- -d / | sort | grep -v "^US/" | grep -v "^posix/" | grep -v "^right/" | while read zone ; do
      echo "${zone}" >> $TZLIST
    done
  )
  for TZ in $(cat $TZLIST); do
    # Add this entry to the keyboard selection menu:
    cat <<EOL >> ${GRUBDIR}/tz.cfg
menuentry "${TZ}" {
  set sl_tz="$TZ"
  export sl_tz
  configfile \$grubdir/grub.cfg
}

EOL
  rm -f $TZLIST

  done
}

# ---------------------------------------------------------------------------
# Action!
# ---------------------------------------------------------------------------

while getopts "a:d:efhm:r:s:t:vz:HR:" Option
do
  case $Option in
    h ) cat <<-"EOH"
	-----------------------------------------------------------------
	$Id: make_slackware_live.sh,v 1.13 2015/12/04 13:51:41 root Exp root $
	-----------------------------------------------------------------
	EOH
        echo "Usage:"
        echo "  $0 [OPTION] ..."
        echo "or:"
        echo "  SL_REPO=/your/repository/dir $0 [OPTION] ..."
        echo ""
        echo "The SL_REPO is the directory that contains the directory"
        echo "  ${DISTRO}-<RELEASE> or ${DISTRO}64-<RELEASE>"
        echo "Current value of SL_REPO : $SL_REPO"
        echo ""
        echo "The script's parameters are:"
        echo " -h                 This help."
        echo " -a arch            Machine architecture (default: ${SL_ARCH})."
        echo "                    Use i586 for a 32bit ISO, x86_64 for 64bit."
        echo " -d desktoptype     SLACKWARE (full Slack), KDE4 (basic KDE4),"
        echo "                    XFCE (basic XFCE), PLASMA5, MATE, CINNAMON."
        echo " -e                 Use ISO boot-load-size of 32 for computers"
        echo "                    where the ISO won't boot otherwise."
        echo " -f                 Forced re-generation of all squashfs modules,"
        echo "                    custom configurations and new initrd.img."
        echo " -m pkglst[,pkglst] Add modules defined by pkglists/<pkglst>,..."
        echo " -r series[,series] Refresh only one or a few package series."
        echo " -s slackrepo_dir   Directory containing ${DISTRO^} repository."
        echo " -t <doc|mandoc>    Trim the ISO for size (remove man and/or doc)"
        echo " -v                 Show debug/error output."
        echo " -z version         Define your ${DISTRO^} version (default: $SL_VERSION)."
        echo " -H hostname        Hostname of the Live OS (default: $LIVE_HOSTNAME)"
        echo " -R runlevel        Runlevel to boot into (default: $RUNLEVEL)"
        exit
        ;;
    a ) SL_ARCH="${OPTARG}"
        ;;
    d ) LIVEDE="$(echo ${OPTARG} |tr a-z A-Z)"
        ;;
    e ) BOOTLOADSIZE=32
        ;;
    f ) FORCE="YES"
        ;;
    m ) SEQ_ADDMOD="${OPTARG}"
        ;;
    r ) REFRESH="${OPTARG}"
        ;;
    s ) SL_REPO="${OPTARG}"
        ;;
    t ) TRIM="${OPTARG}"
        ;;
    v ) DEBUG="YES"
        ;;
    z ) SL_VERSION="${OPTARG}"
        ;;
    H ) LIVE_HOSTNAME="${OPTARG}"
        ;;
    R ) RUNLEVEL=${OPTARG}
        ;;
    * ) echo "You passed an illegal switch to the program!"
        echo "Run '$0 -h' for more help."
        exit
        ;;   # DEFAULT
  esac
done

# End of option parsing.
shift $(($OPTIND - 1))

#  $1 now references the first non option item supplied on the command line
#  if one exists.
# ---------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Some sanity checks first.
# -----------------------------------------------------------------------------

if [ -n "$REFRESH" -a "$FORCE" = "YES" ]; then
  echo ">> Please use only _one_ of the switches '-f' or '-r'!"
  echo ">> Run '$0 -h' for more help."
  exit 1
fi

if [ $RUNLEVEL -ne 3 -a $RUNLEVEL -ne 4 ]; then
  echo ">> Default runlevel other than 3 or 4 is not supported."
  exit 1
fi

# Directory suffix, arch dependent:
if [ "$SL_ARCH" = "x86_64" ]; then
  DIRSUFFIX="64"
  EFIFORM="x86_64"
  EFISUFF="x64"
else
  DIRSUFFIX=""
  EFIFORM="i386"
  EFISUFF="ia32"
fi

# Package root directory, arch dependent:
SL_PKGROOT=${SL_REPO}/${DISTRO}${DIRSUFFIX}-${SL_VERSION}/${DISTRO}${DIRSUFFIX}
DEF_SL_PKGROOT=${SL_PKGROOT}

# Patches root directory, arch dependent:
SL_PATCHROOT=${SL_REPO}/${DISTRO}${DIRSUFFIX}-${SL_VERSION}/patches/packages
DEF_SL_PATCHROOT=${SL_PATCHROOT}

# Do we have a local Slackware repository?
if [ ! -d ${SL_REPO} ]; then
  echo "-- Slackware repository root '${SL_REPO}' does not exist! Exiting."
  exit 1
fi

# Are all the required add-on tools present?
PROG_MISSING=""
for PROGN in mksquashfs unsquashfs grub-mkfont syslinux mkisofs isohybrid installpkg upgradepkg keytab-lilo ; do
  if ! which $PROGN 1>/dev/null 2>/dev/null ; then
    PROG_MISSING="${PROG_MISSING}--   $PROGN\n"
  fi
done
if [ ! -z "$PROG_MISSING" ] ; then
  echo "-- Required program(s) not found in PATH!"
  echo -e ${PROG_MISSING}
  echo "-- Exiting."
  exit 1
fi

[ "$DEBUG" = "NO" ] && DBGOUT="/dev/null" || DBGOUT="/dev/stderr"

# Cleanup if we are FORCEd to rebuild from scratch:
if [ "$FORCE" = "YES" ]; then
  echo "-- Removing old files and directories!"
  umount ${LIVE_ROOTDIR}/{proc,sys,dev} 2>${DBGOUT} || true
  umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
  rm -rf ${LIVE_STAGING}/${LIVEMAIN} ${LIVE_WORK} ${LIVE_ROOTDIR}
fi

# Create output directory for image file:
mkdir -p ${OUTPUT}
if [ $? -ne 0 ]; then
  echo "-- Creation of output directory '${OUTPUT}' failed! Exiting."
  exit 1
fi

# Create temporary directories for building the live filesystem:
for LTEMP in $LIVE_OVLDIR $LIVE_BOOT $LIVE_MOD_SYS $LIVE_MOD_ADD $LIVE_MOD_OPT ; do
   umount ${LTEMP} 2>${DBGOUT} || true
  mkdir -p ${LTEMP}
  if [ $? -ne 0 ]; then
    echo "-- Creation of temporary directory '${LTEMP}' failed! Exiting."
    exit 1
  fi
done

# Create the mount point for our Slackware filesystem:
if [ ! -d ${LIVE_ROOTDIR} ]; then
  mkdir -p ${LIVE_ROOTDIR}
  if [ $? -ne 0 ]; then
    echo "-- Creation of moint point '${LIVE_ROOTDIR}' failed! Exiting."
    exit 1
  fi
  chmod 775 ${LIVE_ROOTDIR}
else
  echo "-- Found an existing live root directory at '${LIVE_ROOTDIR}'".
  echo "-- Check the content and deal with it, then remove that directory."
  echo "-- Exiting now."
  exit 1
fi

# ----------------------------------------------------------------------------
# Install package series:
# ----------------------------------------------------------------------------

unset INSTDIR
RODIRS="${LIVE_BOOT}"
# Create the verification file for the install_pkgs function:
echo "${THEDATE} (${BUILDER})" > ${LIVE_BOOT}/${MARKER}

# Determine which module sequence we have to build:
case "$LIVEDE" in
  SLACKWARE) MSEQ="${SEQ_SLACKWARE}" ;;
       XFCE) MSEQ="${SEQ_XFCEBASE}" ;;
       KDE4) MSEQ="${SEQ_KDE4BASE}" ;;
    PLASMA5) MSEQ="${SEQ_PLASMA5}" ;;
       MATE) MSEQ="${SEQ_MSB}" ;;
   CINNAMON) MSEQ="${SEQ_CIN}" ;;
          *) if [ -n "${SEQ_CUSTOM}" ]; then
               # Custom distribution with a predefined package list:
               MSEQ="${SEQ_CUSTOM}"              
             else
               echo "** Unsupported configuration '$LIVEDE'"; exit 1
             fi
             ;;
esac

# Do we need to create/include additional module(s) defined by a pkglist:
if [ -n "$SEQ_ADDMOD" ]; then
  MSEQ="${MSEQ} pkglist:${SEQ_ADDMOD}"
fi

echo "-- Creating '${LIVEDE}' image."

# Module sequence can be composed of multiple sub-sequences:
for MSUBSEQ in ${MSEQ} ; do

  SL_SERIES="$(echo ${MSUBSEQ} |cut -d: -f2 |tr , ' ')"
  # MTYPE can be "tagfile", "local" or "pkglist"
  # If MTYPE was not specified, by default it is "pkglist":
  MTYPE="$(echo ${MSUBSEQ} |cut -d: -f1 |tr , ' ')"
  if [ "${MTYPE}" = "${SL_SERIES}" ]; then MTYPE="pkglist" ; fi

  # We prefix our own modules based on the source of the package list:
  case "$MTYPE" in
    tagfile) MNUM="0010" ;;
    pkglist) MNUM="0020" ;;
      local) MNUM="0030" ;;
          *) echo "** Unknown package source '$MTYPE'"; exit 1 ;;
  esac

for SPS in ${SL_SERIES} ; do

  INSTDIR=${LIVE_WORK}/${SPS}_$$
  mkdir -p ${INSTDIR}

  if [ "$FORCE" = "YES" -o $(echo ${REFRESH} |grep -wq ${SPS} ; echo $?) -eq 0 -o ! -f ${LIVE_MOD_SYS}/${MNUM}-${DISTRO}_${SPS}-${SL_VERSION}-${SL_ARCH}.sxz ]; then

    # Following conditions trigger creation of the squashed module:
    # - commandline switch '-f' was used, or;
    # - the module was mentioned in the '-r' commandline switch, or;
    # - the module does not yet exist.

    # Create the verification file for the install_pkgs function:
    echo "${THEDATE} (${BUILDER})" > ${INSTDIR}/${MARKER}

    echo "-- Installing the '${SPS}' series."
    umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
    mount -t overlay -o lowerdir=${RODIRS},upperdir=${INSTDIR},workdir=${LIVE_OVLDIR} overlay ${LIVE_ROOTDIR}

    # Install the package series:
    install_pkgs ${SPS} ${LIVE_ROOTDIR} ${MTYPE}
    umount ${LIVE_ROOTDIR} || true

    if [ "$SPS" = "a" -o "$SPS" = "min" ]; then

      # We need to take care of a few things first:
      KGEN=$(echo ${INSTDIR}/var/log/packages/kernel*modules* |head -1 |rev | cut -d- -f3 |tr _ - |rev)
      KVER=$(ls --indicator-style=none ${INSTDIR}/lib/modules/ |head -1)
      if [ -z "$KVER" ]; then
        echo "-- Could not find installed kernel in '${INSTDIR}'! Exiting."
        exit 1
      else
        # Move the content of the /boot directory out of the minimal system,
        # this will be joined again using overlay:
        rm -rf ${LIVE_BOOT}/boot
        mv ${INSTDIR}/boot ${LIVE_BOOT}/
        # Squash the boot files into a module as a safeguard:
        mksquashfs ${LIVE_BOOT} ${LIVE_MOD_SYS}/0000-${DISTRO}_boot-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M
      fi

    fi

    # Squash the installed package series into a module:
    mksquashfs ${INSTDIR} ${LIVE_MOD_SYS}/${MNUM}-${DISTRO}_${SPS}-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M
    rm -rf ${INSTDIR}/*

    # End result: we have our .sxz file and the INSTDIR is empty again,
    # Next step is to loop-mount the squashfs file onto INSTDIR.

  elif [ "$SPS" = "a" -o "$SPS" = "min" ]; then

    # We need to do a bit more if we skipped creation of 'a' or 'min' module:
    # Extract the content of the /boot directory out of the boot module,
    # else we don't have a /boot ready when we create the ISO.
    # We can not just loop-mount it because we need to write into /boot later:
    rm -rf ${LIVE_BOOT}/boot
    unsquashfs -dest ${LIVE_BOOT}/boottemp ${LIVE_MOD_SYS}/0000-${DISTRO}_boot-${SL_VERSION}-${SL_ARCH}.sxz
    mv ${LIVE_BOOT}/boottemp/* ${LIVE_BOOT}/
    rmdir ${LIVE_BOOT}/boottemp

  fi

  # Add the package series tree to the readonly lowerdirs for the overlay:
  RODIRS="${INSTDIR}:${RODIRS}"

  # Mount the modules for use in the final assembly of the ISO:
  mount -t squashfs -o loop ${LIVE_MOD_SYS}/${MNUM}-${DISTRO}_${SPS}-${SL_VERSION}-${SL_ARCH}.sxz ${INSTDIR}

done
done

# ----------------------------------------------------------------------------
# Modules for all package series are created and loop-mounted.
# Next: system configuration.
# ----------------------------------------------------------------------------

# Configuration mudule will always be created from scratch:
INSTDIR=${LIVE_WORK}/zzzconf_$$
mkdir -p ${INSTDIR}

# -------------------------------------------------------------------------- #
echo "-- Configuring the base system."
# -------------------------------------------------------------------------- #

umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
mount -t overlay -o lowerdir=${RODIRS},upperdir=${INSTDIR},workdir=${LIVE_OVLDIR} overlay ${LIVE_ROOTDIR}

# Determine the kernel version in the Live OS:
KGEN=$(echo ${LIVE_ROOTDIR}/var/log/packages/kernel*modules* |head -1 |rev | cut -d- -f3 |tr _ - |rev)
KVER=$(ls --indicator-style=none ${LIVE_ROOTDIR}/lib/modules/ |head -1)

# Configure hostname and network:
echo "${LIVE_HOSTNAME}.example.net" > ${LIVE_ROOTDIR}/etc/HOSTNAME
if [ -f ${LIVE_ROOTDIR}/etc/NetworkManager/NetworkManager.conf ]; then
  sed -i -e "s/^hostname=.*/hostname=${LIVE_HOSTNAME}/" \
    ${LIVE_ROOTDIR}/etc/NetworkManager/NetworkManager.conf
fi
sed -e "s/^\(127.0.0.1\t*\)darkstar.*/\1${LIVE_HOSTNAME}.example.net ${LIVE_HOSTNAME}/" \
  -i ${LIVE_ROOTDIR}/etc/hosts

# Make sure we can access DNS straight away:
cat <<EOT >> ${LIVE_ROOTDIR}/etc/resolv.conf
nameserver 8.8.4.4
nameserver 8.8.8.8

EOT

# Configure en_US.UTF-8 as the default locale (can be overridden on boot):
if grep -q "^ *export LANG=" ${LIVE_ROOTDIR}/etc/profile.d/lang.sh ; then
  sed -e "s/^ *export LANG=.*/export LANG=en_US.UTF-8/" -i ${LIVE_ROOTDIR}/etc/profile.d/lang.sh
else
  echo "export LANG=en_US.UTF-8" >> ${LIVE_ROOTDIR}/etc/profile.d/lang.sh
fi

# Set timezone to UTC:
cp -a ${LIVE_ROOTDIR}/usr/share/zoneinfo/UTC ${LIVE_ROOTDIR}/etc/localtime
rm ${LIVE_ROOTDIR}/etc/localtime-copied-from
ln -s /usr/share/zoneinfo/UTC ${LIVE_ROOTDIR}/etc/localtime-copied-from

# Configure the hardware clock to be interpreted as UTC as well:
cat <<EOT > ${LIVE_ROOTDIR}/etc/hardwareclock 
# /etc/hardwareclock
#
# Tells how the hardware clock time is stored.
# You should run timeconfig to edit this file.

UTC
EOT

# Configure a nice default console font that can handle Unicode:
cat <<EOT >${LIVE_ROOTDIR}/etc/rc.d/rc.font
#!/bin/sh
#
# This selects your default screen font from among the ones in
# /usr/share/kbd/consolefonts.
#
#setfont -v

# Use Terminus font to work better with the Unicode-enabled console
# (configured in /etc/lilo.conf)
setfont -v ter-120b
EOT
chmod +x ${LIVE_ROOTDIR}/etc/rc.d/rc.font

# Enable mouse support in runlevel 3:
cat <<"EOM" > ${LIVE_ROOTDIR}/etc/rc.d/rc.gpm
#!/bin/sh
# Start/stop/restart the GPM mouse server:
[ ! -x /usr/sbin/gpm ] && return
MTYPE="imps2"
if [ "$1" = "stop" ]; then
  echo "Stopping gpm..."
  /usr/sbin/gpm -k
elif [ "$1" = "restart" ]; then
  echo "Restarting gpm..."
  /usr/sbin/gpm -k
  sleep 1
  /usr/sbin/gpm -m /dev/mouse -t ${MTYPE}
else # assume $1 = start:
  echo "Starting gpm:  /usr/sbin/gpm -m /dev/mouse -t ${MTYPE}"
  /usr/sbin/gpm -m /dev/mouse -t ${MTYPE}
fi
EOM
chmod +x ${LIVE_ROOTDIR}/etc/rc.d/rc.gpm

# Remove ssh server keys - new unique keys will be generated
# at first boot of the live system: 
rm -f ${LIVE_ROOTDIR}/etc/ssh/*key*

# Sanitize /etc/fstab :
cat <<EOT > ${LIVE_ROOTDIR}/etc/fstab
proc      /proc       proc        defaults   0   0
sysfs     /sys        sysfs       defaults   0   0
tmpfs     /tmp        tmpfs       defaults,nodev,nosuid,mode=1777  0   0
tmpfs     /var/tmp    tmpfs       defaults,nodev,nosuid,mode=1777  0   0
tmpfs     /dev/shm    tmpfs       defaults,nodev,nosuid,mode=1777  0   0
devpts    /dev/pts    devpts      gid=5,mode=620   0   0
none      /           tmpfs       defaults   1   1

EOT

# Prevent loop devices (sxz modules) from appearing in filemanagers:
mkdir -p ${LIVE_ROOTDIR}/etc/udev/rules.d
cat <<EOL > ${LIVE_ROOTDIR}/etc/udev/rules.d/11-local.rules
# Prevent loop devices (mounted sxz modules) from appearing in
# filemanager panels - http://www.seguridadwireless.net

# Hidden loops for udisks:
KERNEL=="loop*", ENV{UDISKS_PRESENTATION_HIDE}="1"

# Hidden loops for udisks2:
KERNEL=="loop*", ENV{UDISKS_IGNORE}="1"
EOL

# Set a root password.
echo "root:${ROOTPW}" | chpasswd --root ${LIVE_ROOTDIR}

# Create a nonprivileged user account "live":
chroot ${LIVE_ROOTDIR} /usr/sbin/useradd -c "Slackware Live User" -g users -G wheel,audio,cdrom,floppy,plugdev,video,power,netdev,lp,scanner,kmem -u 1000 -d /home/live -m -s /bin/bash live
echo "live:${LIVEPW}" | chpasswd --root ${LIVE_ROOTDIR}

# Configure suauth:
cat <<EOT >${LIVE_ROOTDIR}/etc/suauth
root:live:OWNPASS
root:ALL EXCEPT GROUP wheel:DENY
EOT
chmod 600 ${LIVE_ROOTDIR}/etc/suauth

# Configure sudoers:
chmod 640 ${LIVE_ROOTDIR}/etc/sudoers
sed -i ${LIVE_ROOTDIR}/etc/sudoers -e 's/# *\(%wheel\sALL=(ALL)\sALL\)/\1/'
chmod 440 ${LIVE_ROOTDIR}/etc/sudoers

# Enable a Slackware mirror for slackpkg:
cat <<EOT >> ${LIVE_ROOTDIR}/etc/slackpkg/mirrors
#http://mirrors.slackware.com/slackware/slackware${DIRSUFFIX}-${SL_VERSION}/
http://ftp.osuosl.org/.2/slackware/slackware${DIRSUFFIX}-${SL_VERSION}/
EOT

## Blacklist the l10n packages;
#cat << EOT >> ${LIVE_ROOTDIR}/etc/slackpkg/blacklist
#
## Blacklist the l10n packages;
#calligra-l10n-
#kde-l10n-
#
#EOT

# If we added slackpkg+ for easier system management, let's configure it too.
# Update the cache for slackpkg:
echo "-- Creating slackpkg cache, takes a few seconds..."
chroot "${LIVE_ROOTDIR}" /bin/bash <<EOSL 2>${DBGOUT}

if [ -f var/log/packages/slackpkg+-* ] ; then
  cat <<EOPL > etc/slackpkg/slackpkgplus.conf
SLACKPKGPLUS=on
VERBOSE=1
ALLOW32BIT=off
USEBL=1
WGETOPTS="--timeout=20 --tries=2"
GREYLIST=on
PKGS_PRIORITY=( restricted alienbob ktown_testing )
REPOPLUS=( slackpkgplus restricted alienbob ktown_testing )
MIRRORPLUS['slackpkgplus']=http://slakfinder.org/slackpkg+/
MIRRORPLUS['restricted']=http://taper.alienbase.nl/mirrors/people/alien/restricted_sbrepos/${SL_VERSION}/${SL_ARCH}/
MIRRORPLUS['alienbob']=http://taper.alienbase.nl/mirrors/people/alien/sbrepos/${SL_VERSION}/${SL_ARCH}/
MIRRORPLUS['ktown_testing']=http://taper.alienbase.nl/mirrors/alien-kde/${SL_VERSION}/testing/${SL_ARCH}/
MIRRORPLUS['mate_testing']=http://slackware.uk/msb/testing/1.12/${SL_ARCH}/

EOPL
fi

/usr/sbin/slackpkg -batch=on update gpg
/usr/sbin/slackpkg -batch=on update

EOSL

if [ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.networkmanager ]; then
  # Enable NetworkManager if present:
  chmod +x ${LIVE_ROOTDIR}/etc/rc.d/rc.networkmanager
  # And disable Slackware's own way of configuring eth0:
  cat <<EOT > ${LIVE_ROOTDIR}/etc/rc.d/rc.inet1.conf
IFNAME[0]="eth0"
IPADDR[0]=""
NETMASK[0]=""
USE_DHCP[0]=""
DHCP_HOSTNAME[0]=""

GATEWAY=""
DEBUG_ETH_UP="no"
EOT

  # Ensure that NetworkManager uses its internal DHCP client - seems to give
  # better compliancy:
  sed -e "s/^dhcp=dhcpcd/#&/" -e "s/^#\(dhcp=internal\)/\1/" \
      -i ${LIVE_ROOTDIR}/etc/NetworkManager/NetworkManager.conf

else
  # Use Slackware's own network configurion routing for eth0 in the base image:
  cat <<EOT > ${LIVE_ROOTDIR}/etc/rc.d/rc.inet1.conf
IFNAME[0]="eth0"
IPADDR[0]=""
NETMASK[0]=""
USE_DHCP[0]="yes"
DHCP_HOSTNAME[0]="${LIVE_HOSTNAME}"

GATEWAY=""
DEBUG_ETH_UP="no"
EOT
fi

# Add our scripts to the Live OS:
mkdir -p  ${LIVE_ROOTDIR}/usr/local/sbin
install -m0755 ${LIVE_TOOLDIR}/makemod ${LIVE_TOOLDIR}/iso2usb.sh  ${LIVE_ROOTDIR}/usr/local/sbin/

# Only when we find a huge kernel, we will add a harddisk installer
# to the ISO.  The huge kernel does not require an initrd and installation
# to the hard drive will not be complicated.
if [ -f ${LIVE_ROOTDIR}/boot/vmlinuz-huge-* ]; then
  # Extract the 'setup' files we need from the Slackware installer
  # and move them to a single directory in the ISO:
  mkdir -p  ${LIVE_ROOTDIR}/usr/share/${LIVEMAIN}
  cd  ${LIVE_ROOTDIR}/usr/share/${LIVEMAIN}
    uncompressfs ${DEF_SL_PKGROOT}/../isolinux/initrd.img | cpio -i -d -H newc --no-absolute-filenames usr/lib/setup/* sbin/probe sbin/fixdate
    mv -i usr/lib/setup/* sbin/probe sbin/fixdate .
    rm -r usr sbin
  cd -
  # Fix some occurrences of '/mnt' that should not be used in the Live ISO:
  sed -i -e 's, /mnt, ${T_PX},g' -e 's,T_PX=/mnt,T_PX=/setup2hd,g' ${LIVE_ROOTDIR}/usr/share/${LIVEMAIN}/*
  # Fix some occurrences of '/usr/lib/setup/' are covered by $PATH:
  sed -i -e 's,/usr/lib/setup/,,g' -e 's,:/usr/lib/setup,:/usr/share/${LIVEMAIN},g' ${LIVE_ROOTDIR}/usr/share/${LIVEMAIN}/*
  # Add the Slackware Live HD installer:
  mkdir -p ${LIVE_ROOTDIR}/usr/local/sbin
  cat ${LIVE_TOOLDIR}/setup2hd | sed \
    -e "s/@DIRSUFFIX@/$DIRSUFFIX/g" \
    -e "s/@DISTRO@/$DISTRO/g" \
    -e "s/@CDISTRO@/${DISTRO^}/g" \
    -e "s/@UDISTRO@/${DISTRO^^}/g" \
    -e "s/@KVER@/$KVER/g" \
    -e "s/@LIVEDE@/$LIVEDE/g" \
    -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
    -e "s/@MARKER@/$MARKER/g" \
    -e "s/@SL_VERSION@/$SL_VERSION/g" \
    -e "s/@VERSION@/$VERSION/g" \
    > ${LIVE_ROOTDIR}/usr/local/sbin/setup2hd
  chmod 755 ${LIVE_ROOTDIR}/usr/local/sbin/setup2hd
  # Slackware Live HD post-install customization hook:
  if [ -f ${LIVE_TOOLDIR}/setup2hd.local ]; then
    # The '.local' suffix means: install it as a sample file only:
    HOOK_SRC="${LIVE_TOOLDIR}/setup2hd.local"
    HOOK_DST="${LIVE_ROOTDIR}/usr/share/${LIVEMAIN}/setup2hd.$DISTRO.sample"
  elif [ -f ${LIVE_TOOLDIR}/setup2hd.$DISTRO ]; then
    # Install the hook; the file will be sourced by "setup2hd".
    HOOK_SRC="${LIVE_TOOLDIR}/setup2hd.$DISTRO"
    HOOK_DST="${LIVE_ROOTDIR}/usr/share/${LIVEMAIN}/setup2hd.$DISTRO"
  fi
  cat ${HOOK_SRC} | sed \
    -e "s/@DIRSUFFIX@/$DIRSUFFIX/g" \
    -e "s/@DISTRO@/$DISTRO/g" \
    -e "s/@CDISTRO@/${DISTRO^}/g" \
    -e "s/@UDISTRO@/${DISTRO^^}/g" \
    -e "s/@KVER@/$KVER/g" \
    -e "s/@LIVEDE@/$LIVEDE/g" \
    -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
    -e "s/@MARKER@/$MARKER/g" \
    -e "s/@SL_VERSION@/$SL_VERSION/g" \
    -e "s/@VERSION@/$VERSION/g" \
    > ${HOOK_DST}
  chmod 644 ${HOOK_DST}
fi

# Add the documentation:
mkdir -p  ${LIVE_ROOTDIR}/usr/doc/liveslak-${VERSION}
install -m0644 ${LIVE_TOOLDIR}/README* ${LIVE_ROOTDIR}/usr/doc/liveslak-${VERSION}/
mkdir -p  ${LIVE_ROOTDIR}/usr/doc/${DISTRO}${DIRSUFFIX}-${SL_VERSION}
install -m0644 \
  ${DEF_SL_PKGROOT}/../{CHANGES_AND_HINTS,COPY,README,RELEASE_NOTES,*HOWTO}* \
  ${DEF_SL_PKGROOT}/../usb-and-pxe-installers/README* \
  ${LIVE_ROOTDIR}/usr/doc/${DISTRO}${DIRSUFFIX}-${SL_VERSION}/

# -------------------------------------------------------------------------- #
echo "-- Configuring the X base system."
# -------------------------------------------------------------------------- #

# Reduce the number of local consoles, two should be enough:
sed -i -e '/^c3\|^c4\|^c5\|^c6/s/^/# /' ${LIVE_ROOTDIR}/etc/inittab

# Give the 'live' user a face:
cp ${LIVE_TOOLDIR}/blueSW-64px.png ${LIVE_ROOTDIR}/home/live/.face.icon
chown --reference=${LIVE_ROOTDIR}/home/live ${LIVE_ROOTDIR}/home/live/.face.icon
( cd ${LIVE_ROOTDIR}/home/live/ ; ln .face.icon .face )
mkdir -p ${LIVE_ROOTDIR}/usr/share/apps/kdm/pics/users
cp ${LIVE_TOOLDIR}/blueSW-64px.png ${LIVE_ROOTDIR}/usr/share/apps/kdm/pics/users/blues.icon

# Give XDM a nicer look:
mkdir -p ${LIVE_ROOTDIR}/etc/X11/xdm/liveslak-xdm
cp -a ${LIVE_TOOLDIR}/xdm/* ${LIVE_ROOTDIR}/etc/X11/xdm/liveslak-xdm/
# Point xdm to the custom /etc/X11/xdm/liveslak-xdm/xdm-config:
sed -i ${LIVE_ROOTDIR}/etc/rc.d/rc.4 -e 's,bin/xdm -nodaemon,& -config /etc/X11/xdm/liveslak-xdm/xdm-config,'
# Adapt xdm configuration to target architecture:
sed -i "s/@LIBDIR@/lib${DIRSUFFIX}/g" ${LIVE_ROOTDIR}/etc/X11/xdm/liveslak-xdm/xdm-config

# The Xscreensaver should show a blank screen only, to prevent errors about
# missing modules:
echo "mode:           blank" > ${LIVE_ROOTDIR}/home/live/.xscreensaver

# -------------------------------------------------------------------------- #
echo "-- Configuring XFCE."
# -------------------------------------------------------------------------- #

# Prepare some XFCE defaults for the 'live' user and any new users.
# (don't show icons on the desktop for irrelevant stuff).
# Also, allow other people to add their own custom skel*.txz archives:
mkdir -p ${LIVE_ROOTDIR}/etc/skel/
for SKEL in ${LIVE_TOOLDIR}/skel/skel*.txz ; do
  tar -xf ${SKEL} -C ${LIVE_ROOTDIR}/etc/skel/
done

# -------------------------------------------------------------------------- #
echo "-- Configuring KDE4."
# -------------------------------------------------------------------------- #

# Adjust some usability issues with the default desktop layout:
if [ -f ${LIVE_ROOTDIR}/usr/share/apps/plasma/layout-templates/org.kde.plasma-desktop.defaultPanel/contents/layout.js ]; then
  sed -i \
    -e '/showActivityManager/a konsole = panel.addWidget("quicklaunch")' \
    -e '/showActivityManager/a dolphin = panel.addWidget("quicklaunch")' \
    -e '/showActivityManager/a firefox = panel.addWidget("quicklaunch")' \
    -e '$a firefox.writeConfig("iconUrls","file:///usr/share/applications/mozilla-firefox.desktop")' \
    -e '$a dolphin.writeConfig("iconUrls","file:////usr/share/applications/kde4/dolphin.desktop")' \
    -e '$a konsole.writeConfig("iconUrls","file:///usr/share/applications/kde4/konsole.desktop")' \
    -e '/tasks.writeConfig/d' \
    ${LIVE_ROOTDIR}/usr/share/apps/plasma/layout-templates/org.kde.plasma-desktop.defaultPanel/contents/layout.js
fi

# Prepare some KDE4 defaults for the 'live' user and any new users.

# Preselect the user 'live' in KDM:
mkdir -p ${LIVE_ROOTDIR}/var/lib/kdm
cat <<EOT > ${LIVE_ROOTDIR}/var/lib/kdm/kdmsts
[PrevUser]
:0=live
EOT
chmod 600 ${LIVE_ROOTDIR}/var/lib/kdm/kdmsts

# Be gentle to low-performance USB media and limit disk I/O:
mkdir -p  ${LIVE_ROOTDIR}/etc/skel/.kde/share/config
cat <<EOT > ${LIVE_ROOTDIR}/etc/skel/.kde/share/config/nepomukserverrc
[Basic Settings]
Configured repositories=main
Start Nepomuk=false

[Service-nepomukstrigiservice]
autostart=false

[main Settings]
Storage Dir[\$e]=\$HOME/.kde/share/apps/nepomuk/repository/main/
Used Soprano Backend=virtuosobackend
rebuilt index for type indexing=true
EOT

mkdir -p ${LIVE_ROOTDIR}/etc/skel/.config
cat <<EOT > ${LIVE_ROOTDIR}/etc/skel/.config/kwalletrc
[Auto Allow]
kdewallet=Network Management,KDE Daemon,KDE Control Module

[Wallet]
Close When Idle=false
Enabled=true
First Use=true
Use One Wallet=true
EOT

# Start Konsole with a login shell:
mkdir -p ${LIVE_ROOTDIR}/etc/skel/.kde/share/apps/konsole
cat <<EOT > ${LIVE_ROOTDIR}/etc/skel/.kde/share/apps/konsole/Shell.profile
[General]
Command=/bin/bash -l
Name=Shell
Parent=FALLBACK/
EOT
mkdir -p ${LIVE_ROOTDIR}/etc/skel/.config
cat <<EOT >> ${LIVE_ROOTDIR}/etc/skel/.config/konsolerc
[Desktop Entry]
DefaultProfile=Shell.profile

EOT

if [ "$LIVEDE" = "PLASMA5" ]; then

  # -------------------------------------------------------------------------- #
  echo "-- Configuring PLASMA5."
  # -------------------------------------------------------------------------- #

  # Remove the buggy mediacenter session:
  rm ${LIVE_ROOTDIR}/usr/share/xsessions/plasma-mediacenter.desktop || true
  # Set sane SDDM defaults on first boot (root-owned file):
  mkdir -p ${LIVE_ROOTDIR}/var/lib/sddm
  cat <<EOT > ${LIVE_ROOTDIR}/var/lib/sddm/state.conf 
[Last]
# Name of the last logged-in user. This username will be preselected/shown when the login screen shows up
User=live

# Name of the session file of the last session selected. This session will be preselected when the login screen shows up.
Session=/usr/share/xsessions/plasma.desktop

EOT
  chroot ${LIVE_ROOTDIR} chown -R sddm:sddm var/lib/sddm

  # Thanks to Fedora Live: https://git.fedorahosted.org/cgit/spin-kickstarts.git
  mkdir -p ${LIVE_ROOTDIR}/etc/skel/.config/akonadi
  mkdir -p ${LIVE_ROOTDIR}/etc/skel/.kde/share/config

  # Set akonadi backend:
  cat <<AKONADI_EOF >${LIVE_ROOTDIR}/etc/skel/.config/akonadi/akonadiserverrc
[%General]
Driver=QSQLITE3
AKONADI_EOF

  # Disable baloo:
  cat <<BALOO_EOF >${LIVE_ROOTDIR}/etc/skel/.config/baloofilerc
[Basic Settings]
Indexing-Enabled=false
BALOO_EOF

  # Disable kres-migrator:
  cat <<KRES_EOF >${LIVE_ROOTDIR}/etc/skel/.kde/share/config/kres-migratorrc
[Migration]
Enabled=false
KRES_EOF

  # Disable kwallet migrator:
  cat <<KWALLET_EOL >${LIVE_ROOTDIR}/etc/skel/.config/kwalletrc
[Migration]
alreadyMigrated=true
KWALLET_EOL

  # Make sure that Plasma and SDDM work on older GPUs,
  # by forcing Qt5 to use software GL rendering:
  cat <<"EOGL" >> ${LIVE_ROOTDIR}/usr/share/sddm/scripts/Xsetup

OPENGL_VERSION=$(LANG=C glxinfo |grep '^OpenGL version string: ' |head -n 1 |sed -e 's/^OpenGL version string: \([0-9]\).*$/\1/g')
if [ "$OPENGL_VERSION" -lt 2 ]; then
  QT_XCB_FORCE_SOFTWARE_OPENGL=1
  export QT_XCB_FORCE_SOFTWARE_OPENGL
fi

EOGL

  # Workaround a bug where SDDM does not always use the configured keymap:
  echo "setxkbmap" >> ${LIVE_ROOTDIR}/usr/share/sddm/scripts/Xsetup

  # Do not show the blueman applet, Plasma5 has its own BlueTooth widget:
  echo "NotShowIn=KDE;" >> ${LIVE_ROOTDIR}/etc/xdg/autostart/blueman.desktop

fi # End LIVEDE = PLASMA5

# You can define the function 'custom_config()' by uncommenting it in
# the configuration file 'make_slackware_live.conf'.
if type custom_config 1>/dev/null 2>/dev/null ; then

  # -------------------------------------------------------------------------- #
  echo "-- Configuring ${LIVEDE} by calling 'custom_config()'."
  # -------------------------------------------------------------------------- #

  # This is particularly useful if you defined a non-standard "LIVEDE"
  # in 'make_slackware_live.conf', in which case you must specify your custom
  # package sequence in the variable "SEQ_CUSTOM" in that same .conf file.
  custom_config

fi

# Workaround a bug where our Xkbconfig is not loaded sometimes:
echo "setxkbmap" > ${LIVE_ROOTDIR}/home/live/.xprofile

# Give the live user a copy of our XFCE (and more) skeleton configuration:
cd ${LIVE_ROOTDIR}/etc/skel/
  find . -exec cp -a --parents "{}" ${LIVE_ROOTDIR}/home/live/ \;
cd - 1>/dev/null

# Make sure that user 'live' owns her own files:
chroot ${LIVE_ROOTDIR} chown -R live:users home/live

# -------------------------------------------------------------------------- #
echo "-- Tweaking system startup."
# -------------------------------------------------------------------------- #

# Configure the default DE when running startx:
if [ "$LIVEDE" = "SLACKWARE" ]; then
  ln -sf xinitrc.kde ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc
elif [ "$LIVEDE" = "KDE4" ]; then
  ln -sf xinitrc.kde ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc
elif [ "$LIVEDE" = "PLASMA5" ]; then
  ln -sf xinitrc.plasma ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc
elif [ "$LIVEDE" = "MATE" ]; then
  ln -sf xinitrc.mate-session ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc
elif [ "$LIVEDE" = "CINNAMON" ]; then
  ln -sf xinitrc.cinnamon-session ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc
elif [ -f ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc.xfce ]; then
  ln -sf xinitrc.xfce ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc
fi

# Configure the default runlevel:
sed -i ${LIVE_ROOTDIR}/etc/inittab -e "s/\(id:\).\(:initdefault:\)/\1${RUNLEVEL}\2/"

# Disable unneeded services:
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.acpid ] && chmod -x ${LIVE_ROOTDIR}/etc/rc.d/rc.acpid
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.pcmcia ] && chmod -x ${LIVE_ROOTDIR}/etc/rc.d/rc.pcmcia
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.pulseaudio ] && chmod -x ${LIVE_ROOTDIR}/etc/rc.d/rc.pulseaudio
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.yp ] && chmod -x ${LIVE_ROOTDIR}/etc/rc.d/rc.yp

# But enable NFS client support:
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.rpc ] && chmod +x ${LIVE_ROOTDIR}/etc/rc.d/rc.rpc

# Add a softvol pre-amp to ALSA - some computers have too low volumes.
# If etc/asound.conf exists it's configuring ALSA to use Pulse,
# so in that case the pre-amp is not needed:
if [ ! -f ${LIVE_ROOTDIR}/etc/asound.conf ]; then
  cat <<EOAL > ${LIVE_ROOTDIR}/etc/asound.conf
pcm.!default {
  type asym
  playback.pcm "plug:softvol"
  capture.pcm "plug:dsnoop"
}

pcm.softvol {
  type softvol
  slave.pcm "dmix"
  control { name "PCM"; card 0; }
  max_dB 32.0
}
EOAL
else
  if ! grep -q sysdefault ${LIVE_ROOTDIR}/etc/asound.conf ; then
    # If pulse is used, configure a fallback to use the system default
    # or else there will not be sound on first boot:
    sed -i ${LIVE_ROOTDIR}/etc/asound.conf \
        -e '/type pulse/ a \ \ fallback "sysdefault"'
  fi
fi

# Skip all filesystem checks at boot:
touch ${LIVE_ROOTDIR}/etc/fastboot

# Disable the root filesystem check altogether:
sed -i -e '/^if \[ ! \$READWRITE = yes/,/^fi # Done checking root filesystem/s/^/#/' ${LIVE_ROOTDIR}/etc/rc.d/rc.S

# We will not write to the hardware clock:
sed -i -e '/systohc/s/^/# /' ${LIVE_ROOTDIR}/etc/rc.d/rc.6

# Run some package setup scripts (usually run by the slackware installer),
# as well as some of the delaying commands in rc.M and rc.modules:
chroot ${LIVE_ROOTDIR} /bin/bash <<EOCR
# Rebuild SSL certificate database:
/usr/sbin/update-ca-certificates --fresh 1>/dev/null 2>${DBGOUT}

# Run bits from rc.M so we won't need to run them again in the live system:
/sbin/depmod $KVER
/sbin/ldconfig
EOCR

chroot ${LIVE_ROOTDIR} /bin/bash <<EOCR
# Update the desktop database:
if [ -x /usr/bin/update-desktop-database ]; then
  /usr/bin/update-desktop-database /usr/share/applications > /dev/null 2>${DBGOUT}
fi

# Update hicolor theme cache:
if [ -d /usr/share/icons/hicolor ]; then
  if [ -x /usr/bin/gtk-update-icon-cache ]; then
    /usr/bin/gtk-update-icon-cache -f -t /usr/share/icons/hicolor 1>/dev/null 2>${DBGOUT}
  fi
fi

# Update the mime database:
if [ -x /usr/bin/update-mime-database ]; then
  /usr/bin/update-mime-database /usr/share/mime >/dev/null 2>${DBGOUT}
fi

# Font configuration:
if [ -x /usr/bin/fc-cache ]; then
  for fontdir in 100dpi 75dpi OTF Speedo TTF Type1 cyrillic ; do
    if [ -d /usr/share/fonts/\$fontdir ]; then
      mkfontscale /usr/share/fonts/\$fontdir 1>/dev/null 2>${DBGOUT}
      mkfontdir /usr/share/fonts/\$fontdir 1>/dev/null 2>${DBGOUT}
    fi
  done
  if [ -d /usr/share/fonts/misc ]; then
    mkfontscale /usr/share/fonts/misc  1>/dev/null 2>${DBGOUT}
    mkfontdir -e /usr/share/fonts/encodings -e /usr/share/fonts/encodings/large /usr/share/fonts/misc 1>/dev/null 2>${DBGOUT}
  fi
  /usr/bin/fc-cache -f 1>/dev/null 2>${DBGOUT}
fi

if [ -x /usr/bin/update-gtk-immodules ]; then
  /usr/bin/update-gtk-immodules
fi
if [ -x /usr/bin/update-gdk-pixbuf-loaders ]; then
  /usr/bin/update-gdk-pixbuf-loaders
fi
if [ -x /usr/bin/update-pango-querymodules ]; then
  /usr/bin/update-pango-querymodules
fi

if [ -x /usr/bin/glib-compile-schemas ]; then
  /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas >/dev/null 2>${DBGOUT}
fi

# Delete unwanted cache files:
find usr/share/icons -name icon-theme.cache -exec rm "{}" \;
EOCR

# Disable above commands in rc.M and rc.modules:
sed -e "s% /usr/bin/update.*verbose%#&%" -i ${LIVE_ROOTDIR}/etc/rc.d/rc.M 
sed -e '/^ *\/usr\/bin\/glib-c/ s, /usr/bin/glib-c,#&,' -i ${LIVE_ROOTDIR}/etc/rc.d/rc.M
sed -e "s% /sbin/depmod -%#&%" -i ${LIVE_ROOTDIR}/etc/rc.d/rc.modules 

# If we detect a NVIDIA driver, then run the nvidia install routine:
cat <<EOT >> ${LIVE_ROOTDIR}/etc/rc.d/rc.local

# Deal with the presence of NVIDIA drivers:
if [ -x /usr/sbin/nvidia-switch ]; then
  if [ -f /usr/lib${DIRSUFFIX}/xorg/modules/extensions/libglx.so.*-nvidia -a -f /usr/lib${DIRSUFFIX}/xorg/modules/drivers/nvidia_drv.so ]; then
    echo "-- Installing binary Nvidia drivers:  /usr/sbin/nvidia-switch --install"
    # The nvidia kernel module needs to ne announced to the kernel.
    # This costs a few seconds in additional boot-up time unfortunately:
    /sbin/depmod -a
    /usr/sbin/nvidia-switch --install
  fi
  # For CUDA/OpenCL to work after reboot, create missing nvidia device nodes:
  /usr/bin/nvidia-modprobe -c 0 -u
else
  # Take care of a reboot where nvidia drivers disappeared
  # afer being used earlier, by restoring the original libraries:
  if ls /usr/lib${DIRSUFFIX}/xorg/modules/extensions/libglx.so-xorg 1>/dev/null 2>/dev/null ; then
    mv /usr/lib${DIRSUFFIX}/xorg/modules/extensions/libglx.so{-xorg,} 2>/dev/null
    mv /usr/lib${DIRSUFFIX}/xorg/modules/extensions/libglx.la{-xorg,} 2>/dev/null
  fi
  if ls /usr/lib${DIRSUFFIX}/libGL.so.*-xorg 1>/dev/null 2>/dev/null ; then
    LIBGL=\$(ls -1 /usr/lib${DIRSUFFIX}/libGL.so.*-xorg |rev |cut -d/ -f1 |cut -d- -f2- |rev)
    mv /usr/lib${DIRSUFFIX}/\${LIBGL}-xorg /usr/lib${DIRSUFFIX}/\${LIBGL} 2>/dev/null
    ln -sf \${LIBGL} /usr/lib${DIRSUFFIX}/libGL.so.1 2>/dev/null
    ln -sf \${LIBGL} /usr/lib${DIRSUFFIX}/libGL.so 2>/dev/null
    mv /usr/lib${DIRSUFFIX}/libGL.la-xorg /usr/lib${DIRSUFFIX}/libGL.la 2>/dev/null
  fi
  if ls /usr/lib${DIRSUFFIX}/libEGL.so.*-xorg 1>/dev/null 2>/dev/null   ; then
    LIBEGL=\$(ls -1 /usr/lib${DIRSUFFIX}/libEGL.so.*-xorg |rev |cut -d/ -f1 |cut -d- -f2- |rev)
    mv /usr/lib${DIRSUFFIX}/\${LIBEGL}-xorg /usr/lib${DIRSUFFIX}/\${LIBEGL} 2>/dev/null
    ln -sf \${LIBEGL} /usr/lib${DIRSUFFIX}/libEGL.so.1 2>/dev/null
    ln -sf \${LIBEGL} /usr/lib${DIRSUFFIX}/libEGL.so 2>/dev/null
  fi
fi
EOT

# Clean out the unneeded stuff:
# Note: this will fail when a directory is encountered. This failure points
# to a packaging issue; find and fix the responsible package.
rm -f ${LIVE_ROOTDIR}/tmp/[A-Za-z]*
rm -f ${LIVE_ROOTDIR}/var/mail/*
rm -f ${LIVE_ROOTDIR}/root/.bash*

# Create a locate cache:
echo "-- Creating locate cache, takes a few seconds..."
chroot ${LIVE_ROOTDIR} /etc/cron.daily/slocate 2>${DBGOUT}

# -----------------------------------------------------------------------------
# Done with configuring the live system!
# -----------------------------------------------------------------------------

# Squash the configuration into its own module:
umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
mksquashfs ${INSTDIR} ${LIVE_MOD_SYS}/0099-${DISTRO}_zzzconf-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M
rm -rf ${INSTDIR}/*

# End result: we have our .sxz file and the INSTDIR is empty again,
# Next step is to loop-mount the squashfs file onto INSTDIR.

# Add the system configuration tree to the readonly lowerdirs for the overlay:
RODIRS="${INSTDIR}:${RODIRS}"

# Mount the module for use in the final assembly of the ISO:
mount -t squashfs -o loop ${LIVE_MOD_SYS}/0099-${DISTRO}_zzzconf-${SL_VERSION}-${SL_ARCH}.sxz ${INSTDIR}

unset INSTDIR

# -----------------------------------------------------------------------------
# Prepare the system for live booting.
# -----------------------------------------------------------------------------

echo "-- Preparing the system for live booting."
umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
mount -t overlay -o lowerdir=${RODIRS%:*},upperdir=${LIVE_BOOT},workdir=${LIVE_OVLDIR} overlay ${LIVE_ROOTDIR}

mount --bind /proc ${LIVE_ROOTDIR}/proc
mount --bind /sys ${LIVE_ROOTDIR}/sys
mount --bind /dev ${LIVE_ROOTDIR}/dev

# Determine the installed kernel version:
KGEN=$(echo ${LIVE_ROOTDIR}/var/log/packages/kernel*modules* |head -1 |rev | cut -d- -f3 |tr _ - |rev)
KVER=$(ls --indicator-style=none ${LIVE_ROOTDIR}/lib/modules/ |head -1)

# Create an initrd for the generic kernel, using a modified init script:
echo "-- Creating initrd for kernel-generic $KVER ..."
chroot ${LIVE_ROOTDIR} /sbin/mkinitrd -c -w ${WAIT} -l us -o /boot/initrd_${KVER}.img -k ${KVER} -m ${KMODS} -L -C dummy 1>${DBGOUT} 2>${DBGOUT}
# Modify the initrd content for the Live OS:
cat $LIVE_TOOLDIR/liveinit | sed \
  -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
  -e "s/@MARKER@/$MARKER/g" \
  -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
  -e "s/@PERSISTENCE@/$PERSISTENCE/g" \
  -e "s/@DARKSTAR@/$LIVE_HOSTNAME/g" \
  > ${LIVE_ROOTDIR}/boot/initrd-tree/init
cat /dev/null > ${LIVE_ROOTDIR}/boot/initrd-tree/luksdev
# We do not add openobex to the initrd and don't want to see irrelevant errors:
rm ${LIVE_ROOTDIR}/boot/initrd-tree/lib/udev/rules.d/*openobex*rules 2>${DBGOUT} || true
if [ "$NFSROOTSUP" = "YES" ]; then
  # Add dhcpcd for NFS root support:
  DHCPD_PKG=$(find ${DEF_SL_PKGROOT}/../ -name "dhcpcd-*.t?z" |head -1)
  tar -C ${LIVE_ROOTDIR}/boot/initrd-tree/ -xf ${DHCPD_PKG} \
    var/lib/dhcpcd lib/dhcpcd sbin/dhcpcd usr/lib${DIRSUFFIX}/dhcpcd \
    etc/dhcpcd.conf.new
  mv ${LIVE_ROOTDIR}/boot/initrd-tree/etc/dhcpcd.conf{.new,}
  # Add just the right kernel network modules by pruning unneeded stuff:
  KMODS_PKG=$(find ${DEF_SL_PKGROOT}/../ -name "kernel-modules-*$(echo $KVER |tr - _)*.t?z" |head -1)
  KMODS_TEMP=$(mktemp -d -p /mnt -t liveslak.XXXXXX)
  if [ ! -d $KMODS_TEMP ]; then
    echo "*** Failed to create a temporary extraction directory for the initrd!"
    exit 1
  fi
  # We need to extract the full kernel-modules package for deps resolving:
  tar -C ${KMODS_TEMP} -xf ${KMODS_PKG}
  # Get the kernel modules:
  cd ${KMODS_TEMP}
    cp -a --parents lib/modules/${KVER}/${NETMODS} \
      ${LIVE_ROOTDIR}/boot/initrd-tree/
  cd - 1>/dev/null
  # Prune the ones we do not need:
  for KNETRM in ${NETEXCL} ; do
    find ${LIVE_ROOTDIR}/boot/initrd-tree/lib/modules/${KVER}/${NETMODS} \
      -name $KNETRM -depth -exec rm -rf {} \;
  done
  # Add any dependency modules:
  for MODULE in $(find ${LIVE_ROOTDIR}/boot/initrd-tree/lib/modules/${KVER}/${NETMODS} -type f -exec basename {} .ko \;) ; do
    /sbin/modprobe --dirname ${KMODS_TEMP} --set-version $KVER --show-depends --ignore-install $MODULE 2>/dev/null |grep "^insmod " |cut -f 2 -d ' ' |while read SRCMOD; do
      if [ "$(basename $SRCMOD .ko)" != "$MODULE" ]; then
        cd ${KMODS_TEMP}
          # Need to strip ${KMODS_TEMP} from the start of ${SRCMOD}:
          cp -a --parents $(echo $SRCMOD |sed 's|'${KMODS_TEMP}'/|./|' ) \
            ${LIVE_ROOTDIR}/boot/initrd-tree/
        cd - 1>/dev/null
      fi
    done
  done
  # Remove the temporary tree:
  rm -rf ${KMODS_TEMP}
  # We added extra modules to the initrd, so we run depmod again:
  chroot ${LIVE_ROOTDIR}/boot/initrd-tree /sbin/depmod $KVER
  # Add the firmware for network cards that need them:
  KFW_PKG=$(find ${DEF_SL_PKGROOT}/../ -name "kernel-firmware-*.t?z" |head -1)
  tar tf ${KFW_PKG} |grep -E "($(echo $NETFIRMWARE |tr ' ' '|'))" \
    |xargs tar -C ${LIVE_ROOTDIR}/boot/initrd-tree/ -xf ${KFW_PKG} \
    2>/dev/null || true
fi
# Wrap up the initrd.img again:
( cd ${LIVE_ROOTDIR}/boot/initrd-tree
  find . | cpio -o -H newc | $COMPR >${LIVE_ROOTDIR}/boot/initrd_${KVER}.img 2>${DBGOUT}
)
rm -rf ${LIVE_ROOTDIR}/boot/initrd-tree

# ... and cleanup these mounts again:
umount ${LIVE_ROOTDIR}/{proc,sys,dev} || true
umount ${LIVE_ROOTDIR} || true
# Paranoia:
[ ! -z "${LIVE_BOOT}" ] && rm -rf ${LIVE_BOOT}/{etc,tmp,usr,var} 1>${DBGOUT} 2>${DBGOUT}

# Copy kernel and move the modified initrd (we do not need it in the Live OS).
# Note to self: syslinux does not 'see' files unless they are DOS 8.3 names?
rm -rf ${LIVE_STAGING}/boot
mkdir -p ${LIVE_STAGING}/boot
cp -a ${LIVE_BOOT}/boot/vmlinuz-generic*-$KGEN ${LIVE_STAGING}/boot/generic
mv ${LIVE_BOOT}/boot/initrd_${KVER}.img ${LIVE_STAGING}/boot/initrd.img

# Squash the boot directory into its own module:
mksquashfs ${LIVE_BOOT} ${LIVE_MOD_SYS}/0000-${DISTRO}_boot-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M

# Copy the syslinux configuration.
# The next block checks here for a possible UEFI grub boot image:
cp -a ${LIVE_TOOLDIR}/syslinux ${LIVE_STAGING}/boot/

# EFI support always for 64bit architecture, but conditional for 32bit.
if [ "$SL_ARCH" = "x86_64" -o "$EFI32" = "YES" ]; then
  # Copy the UEFI boot directory structure:
  mkdir -p ${LIVE_STAGING}/EFI/BOOT
  cp -a ${LIVE_TOOLDIR}/EFI/BOOT/{grub-embedded.cfg,make-grub.sh,*.txt,theme} ${LIVE_STAGING}/EFI/BOOT/

  # Create the grub fonts used in the theme:
  for FSIZE in 5 10 12; do
    grub-mkfont -s ${FSIZE} -av \
      -o ${LIVE_STAGING}/EFI/BOOT/theme/dejavusansmono${FSIZE}.pf2 \
      /usr/share/fonts/TTF/DejaVuSansMono.ttf \
      | grep "^Font name: "
  done

  # The grub-embedded.cfg in the bootx64.efi/bootia32.efi looks for this file:
  touch ${LIVE_STAGING}/EFI/BOOT/${MARKER}

  # Generate the UEFI grub boot image if needed:
  if [ ! -f ${LIVE_STAGING}/EFI/BOOT/boot${EFISUFF}.efi -o ! -f ${LIVE_STAGING}/boot/syslinux/efiboot.img ]; then
    ( cd ${LIVE_STAGING}/EFI/BOOT
      sed -i -e "s/SLACKWARELIVE/${MARKER}/g" grub-embedded.cfg
      sh make-grub.sh EFIFORM=${EFIFORM} EFISUFF=${EFISUFF}
    )
  fi

  # Generate the grub configuration for UEFI boot:
  gen_uefimenu ${LIVE_STAGING}/EFI/BOOT
fi # End EFI support menu.

if [ "$SYSMENU" = "NO" ]; then
  # Simple isolinux choices, no UEFI support.
  echo "include syslinux.cfg" > ${LIVE_STAGING}/boot/syslinux/isolinux.cfg
else
  # NOTE: Convert a PNG image to VESA bitmap before using it with vesamenu:
  # $ convert -depth 16 -colors 65536 in.png out.png
  cp -a /usr/share/syslinux/vesamenu.c32 ${LIVE_STAGING}/boot/syslinux/
  echo "include menu/vesamenu.cfg" > ${LIVE_STAGING}/boot/syslinux/isolinux.cfg
  # Generate the multi-language menu:
  gen_bootmenu ${LIVE_STAGING}/boot/syslinux
fi
for SLFILE in message.txt f2.txt syslinux.cfg lang.cfg ; do
  if [ -f ${LIVE_STAGING}/boot/syslinux/${SLFILE} ]; then
    sed -i ${LIVE_STAGING}/boot/syslinux/${SLFILE} \
      -e "s/@DIRSUFFIX@/$DIRSUFFIX/g" \
      -e "s/@DISTRO@/$DISTRO/g" \
      -e "s/@CDISTRO@/${DISTRO^}/g" \
      -e "s/@UDISTRO@/${DISTRO^^}/g" \
      -e "s/@KVER@/$KVER/g" \
      -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
      -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
      -e "s/@LIVEDE@/$(echo $LIVEDE |sed 's/BASE//')/g" \
      -e "s/@SL_VERSION@/$SL_VERSION/g"
  fi
done
mv ${LIVE_STAGING}/boot/syslinux/memtest ${LIVE_STAGING}/boot/

# Make use of proper console font if we have it available:
if [ -f /usr/share/kbd/consolefonts/${CONSFONT}.gz ]; then
  gunzip -cd /usr/share/kbd/consolefonts/${CONSFONT}.gz > ${LIVE_STAGING}/boot/syslinux/${CONSFONT}
elif [ ! -f ${LIVE_STAGING}/boot/syslinux/${CONSFONT} ]; then
  sed -i -e "s/^font .*/#&/" ${LIVE_STAGING}/boot/syslinux/menu/*menu*.cfg
fi

# -----------------------------------------------------------------------------
# Assemble the ISO
# -----------------------------------------------------------------------------

echo "-- Assemble the ISO image."

# Tag the type of live environment to the ISO filename:
if [ "$LIVEDE" = "SLACKWARE" ]; then
  ISOTAG=""
else
  ISOTAG="-$(echo $LIVEDE |tr A-Z a-z)"
fi

# Copy our stockpile of add-on modules into place:
if [ -f ${LIVE_TOOLDIR}/addons/*.sxz ]; then
  cp ${LIVE_TOOLDIR}/addons/*.sxz ${LIVE_MOD_ADD}/
fi

# If we have optionals, copy those too:
if [ -f ${LIVE_TOOLDIR}/optional/*.sxz ]; then
  cp ${LIVE_TOOLDIR}/optional/*.sxz ${LIVE_MOD_OPT}/
fi

if [ "$LIVEDE" != "XFCE" -a "$LIVEDE" != "SLACKWARE" ]; then
  # KDE/PLASMA etc will profit from accelerated graphics support;
  # however the SLACKWARE ISO should not have any non-Slackware content.
  # You can 'cheat' when building the SLACKWARE ISO by copying the graphics
  # drivers into the 'optional' directory yourself.
  if [ -f ${LIVE_TOOLDIR}/graphics/*${KVER}-*.sxz ]; then
    # Add custom (proprietary) graphics drivers:
    echo "-- Adding binary GPU drivers supporting kernel ${KVER}."
    cp ${LIVE_TOOLDIR}/graphics/*${KVER}-*.sxz ${LIVE_MOD_OPT}/
  fi
fi

# Directory for rootcopy files (everything placed here will be copied
# verbatim into the overlay root):
mkdir -p ${LIVE_STAGING}/rootcopy

# Create an ISO file from the directories found below ${LIVE_STAGING}:
cd ${LIVE_STAGING}

# Determine whether we add UEFI boot capabilities to the ISO:
if [ -f boot/syslinux/efiboot.img ]; then
  UEFI_OPTS="-eltorito-alt-boot -no-emul-boot -eltorito-platform 0xEF -eltorito-boot boot/syslinux/efiboot.img"
else
  UEFI_OPTS=""
fi

mkisofs -o ${OUTPUT}/${DISTRO}${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso \
  -R -J \
  -hide-rr-moved \
  -v -d -N \
  -no-emul-boot -boot-load-size ${BOOTLOADSIZE} -boot-info-table \
  -sort boot/syslinux/iso.sort \
  -b boot/syslinux/isolinux.bin \
  -c boot/syslinux/isolinux.boot \
  ${UEFI_OPTS} \
  -preparer "$(echo $LIVEDE |sed 's/BASE//') Live built by ${BUILDER}" \
  -publisher "The Slackware Linux Project - http://www.slackware.com/" \
  -A "${DISTRO^}-${SL_VERSION} for ${SL_ARCH} ($(echo $LIVEDE |sed 's/BASE//') Live $VERSION)" \
  -V "${MEDIALABEL}" \
  -x ./$(basename ${LIVE_WORK}) \
  -x ./${LIVEMAIN}/bootinst \
  -x boot/syslinux/testing \
  .

# This copy is no longer needed:
rm -rf ./boot

cd - 1>/dev/null

if [ "$SL_ARCH" = "x86_64" -o "$EFI32" = "YES" ]; then
  # Make this a hybrid ISO with UEFI boot support on x86_64.
  # On 32bit, the variable EFI32 must be explicitly enabled.
  SIZEISO=$(stat --printf %s ${OUTPUT}/${DISTRO}${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso)
  # We want no more than 63 sectors, no more than 255 heads, according to
  # recommendations from Thomas Schmitt, xoriso developer.
  if [ $SIZEISO -gt 1073741824 ]; then
    # No more than 63 sectors, no more than 255 heads. We will not try to stick
    # to less than 1024 cylinders though:
    SECTORS=63
    HEADS=255
  else
    # The default values for isohybrid gives us a max size of 1073741824 bytes:
    # We want at most 1024 cylinders for old BIOS; also we want no more than
    # 63 sectors, no more than 255 heads, which leads to a cut-over size:.
    # 64 (heads) *32 (sectors) *1024 (cylinders) *512 (bytes) = 1073741824 bytes.
    SECTORS=32
    HEADS=64
  fi
  isohybrid -s $SECTORS -h $HEADS -u ${OUTPUT}/${DISTRO}${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso
fi # End UEFI hybrid ISO.

cd ${OUTPUT}
  md5sum ${DISTRO}${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso \
    > ${DISTRO}${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso.md5
cd - 1>/dev/null
echo "-- Live ISO image created:"
ls -l ${OUTPUT}/${DISTRO}${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso*

# Clean out the mounts etc:
cleanup

