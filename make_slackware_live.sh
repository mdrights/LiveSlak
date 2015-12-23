#!/bin/bash

# $Id: make_slackware_live.sh,v 1.13 2015/12/04 13:51:41 root Exp root $
# Copyright 2014, 2015  Eric Hameleers, Eindhoven, NL 
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
# - boots using isolinux/extlinux
# - requires kernel >= 4.0 which supports multiple lower layers in overlay
# - uses squashfs to create compressed modules out of directory trees
# - uses overlayfs to bind multiple squashfs modules together
# - you can add your own modules into ./addons/ subdirectory
#
# -----------------------------------------------------------------------------

# Directory where our live tools are stored:
LIVE_TOOLDIR=${LIVE_TOOLDIR:-"$(cd $(dirname $0); pwd)"}

# Load the optional configuration file:
CONFFILE=${LIVE_TOOLDIR}/$(basename $0 .sh).conf
if [ -f ${CONFFILE} ]; then
  echo "-- Loading configuration file."
  . ${CONFFILE}
fi

# Set to "YES" to send error output to the console:
DEBUG=${DEBUG:=NO}

# Set to "YES" in order to delete everything we have,
# and rebuild any pre-existing .sxz modules from scratch:
FORCE=${FORCE:-"NO"}

# Set to 32 to be more compatible with the specs. Slackware uses 4 by default:
BOOTLOADSIZE=${BOOTLOADSIZE:-4}

# The root and live user passwords of the image:
ROOTPW=${ROOTPW:-"root"}
LIVEPW=${LIVEPW:-"live"}

# Custom name for the host:
LIVE_HOSTNAME=${LIVE_HOSTNAME:-"darkstar"}

# What type of Live image?
# Choices are: SLACKWARE, XFCE, KDE4, PLASMA5, MATE, CINNAMON
LIVEDE=${LIVEDE:-"SLACKWARE"}

# What runlevel to use if adding a DE like: XFCE, KDE4, PLASMA5 etc...
RUNLEVEL=${RUNLEVEL:-4}

# Use the graphical syslinux menu (YES or NO)?
SYSMENU=${SYSMENU:-"YES"}

# Console font to use with syslinux for better language support:
CONSFONT=${CONSFONT:-"ter-i16v.psf"}

# This variable can be set to a comma-separated list of package series.
# The squashfs module(s) for these package series will then be re-generated.
# Example commandline parameter: "-r l,kde,kdei"
REFRESH=""

#
# ---------------------------------------------------------------------------
#

# Timestamp:
THEDATE=$(date +%Y%m%d)

# Who built the live image:
BUILDER=${BUILDER:-"Alien BOB"}

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

# Directory suffix, arch dependent:
if [ "$SL_ARCH" = "x86_64" ]; then
  DIRSUFFIX="64"
else
  DIRSUFFIX=""
fi

# Root directory of a Slackware local mirror tree;
# You can define custom repository location (must be in local filesystem)
# for any module in the file ./pkglists/<module>.conf:
SL_REPO=${SL_REPO:-"/mnt/auto/sox/ftp/pub/Linux/Slackware"}

# Package root directory:
SL_PKGROOT=${SL_REPO}/slackware${DIRSUFFIX}-${SL_VERSION}/slackware${DIRSUFFIX}
# Patches root directory:
SL_PATCHROOT=${SL_REPO}/slackware${DIRSUFFIX}-${SL_VERSION}/patches/packages

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
SEQ_PLASMA5="tagfile:a,ap,d,e,f,k,l,n,t,tcl,x,xap,xfce,y pkglist:slackextra,kde4plasma5,plasma5 local:slackpkg+"

# List of Slackware package series with MSB instead of KDE 4 (full install):
# - each will become a squashfs module:
SEQ_MSB="tagfile:a,ap,d,e,f,k,l,n,t,tcl,x,xap,xfce,y pkglist:slackextra,mate local:slackpkg+"

# List of Slackware package series with Cinnamon instead of KDE4 (full install):
# - each will become a squashfs module:
SEQ_CIN="tagfile:a,ap,d,e,f,k,l,n,t,tcl,x,xap,xfce,y pkglist:slackextra,cinnamon local:slackpkg+"

# List of kernel modules required for a live medium to boot properly:
KMODS=${KMODS:-"squashfs:overlay:loop:xhci-pci:ehci-pci:uhci_hcd:usb-storage:hid:usbhid:hid_generic:jbd:mbcache:ext3:ext4:isofs:fat:nls_cp437:nls_iso8859-1:msdos:vfat"}

# What compression to use for the squashfs modules?
# Default is xz, alternatives are gzip, lzma, lzo:
SXZ_COMP=${SXZ_COMP:-"xz"}

# Mount point where we will assemble a Slackware filesystem:
LIVE_ROOTDIR=${LIVE_ROOTDIR:-"/mnt/slackwarelive"}

# Toplevel directory of our staging area:
LIVE_STAGING=${LIVE_STAGING:-"/tmp/slackwarelive_staging"}

# Work directory where we will create all the temporary stuff:
LIVE_WORK=${LIVE_WORK:-"${LIVE_STAGING}/temp"}

# Directory to be used by overlayfs for data manipulation:
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
  umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
  # Need to umount the squashfs modules too:
  umount ${LIVE_WORK}/*_$$ 2>${DBGOUT} || true

  rmdir ${LIVE_ROOTDIR} 2>${DBGOUT}
  rmdir ${LIVE_WORK}/*_$$ 2>${DBGOUT}
  rm ${LIVE_MOD_OPT}/* 2>${DBGOUT} || true
  rm ${LIVE_MOD_ADD}/* 2>${DBGOUT} || true
}
trap 'echo "*** $0 FAILED at line $LINENO ***"; cleanup; exit 1' ERR INT TERM


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

    if [ ! -d ${SL_REPO} ]; then
      echo "-- Slackware repository root '${SL_REPO}' does not exist! Exiting."
      exit 1
    fi

    for PKG in $(cat ${PKGFILE} |grep -v -E '^ *#|^$' |cut -d: -f1); do
      # Look in ./patches ; then ./slackware$DIRSUFFIX ; then ./extra
      # Need to escape any '+' in package names such a 'gtk+2':
      if [ ! -z "${SL_PATCHROOT}" ]; then
        FULLPKG=$(find ${SL_PATCHROOT} -name "${PKG}-*.t?z" 2>/dev/null | grep -E "${PKG//+/\\+}-[^-]+-[^-]+-[^-]+.t?z")
      else
        FULLPKG=""
      fi
      if [ "x${FULLPKG}" = "x" ]; then
        FULLPKG=$(find ${SL_PKGROOT} -name "${PKG}-*.t?z" 2>/dev/null |grep -E "${PKG//+/\\+}-[^-]+-[^-]+-[^-]+.t?z" |head -1)
      else
        echo "-- $PKG found in patches"
      fi
      if [ "x${FULLPKG}" = "x" ]; then
        # One last attempt: look in ./extra
        FULLPKG=$(find $(dirname ${SL_PKGROOT})/extra -name "${PKG}-*.t?z" 2>/dev/null |grep -E "${PKG//+/\\+}-[^-]+-[^-]+-[^-]+.t?z" |head -1)
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
    -e "s/@KVER@/$KVER/g" \
    -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
    -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
    -e "s/@LIVEDE@/$(echo $LIVEDE |sed 's/BASE//')/g" \
    -e "s/@SL_VERSION@/$SL_VERSION/g" \
    > ${MENUROOTDIR}/vesamenu.cfg

  for KBD in $(cat ${LIVE_TOOLDIR}/languages |grep -Ev "(^ *#|^$)" |cut -d, -f3)
  do
    LANCOD=$(cat ${LIVE_TOOLDIR}/languages |grep ",$KBD," |cut -d, -f1)
    LANDSC=$(cat ${LIVE_TOOLDIR}/languages |grep ",$KBD," |cut -d, -f2)
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
      -e "s/@KVER@/$KVER/g" \
      -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
      -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
      -e "s/@LIVEDE@/$(echo $LIVEDE |sed 's/BASE//')/g" \
      -e "s/@SL_VERSION@/$SL_VERSION/g" \
      > ${MENUROOTDIR}/menu_${LANCOD}.cfg

    # Generate custom language selection submenu for selected keyboard:
    for SUBKBD in $(cat ${LIVE_TOOLDIR}/languages |grep -Ev "(^ *#|^$)" |cut -d, -f3) ; do
      cat <<EOL >> ${MENUROOTDIR}/lang_${LANCOD}.cfg
label $(cat ${LIVE_TOOLDIR}/languages |grep ",$SUBKBD," |cut -d, -f1)
  menu label $(cat ${LIVE_TOOLDIR}/languages |grep ",$SUBKBD," |cut -d, -f2)
  kernel /boot/generic
  append initrd=/boot/initrd.img load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=$KBD tz=$(cat ${LIVE_TOOLDIR}/languages |grep ",$SUBKBD," |cut -d, -f4) locale=$(cat ${LIVE_TOOLDIR}/languages |grep ",$SUBKBD," |cut -d, -f5)

EOL
    done

  done

}

#
# Create the grub menu file for UEFI boot:
#
function gen_uefimenu() {

  GRUBDIR="$1"

  # I expect the directory to exist... but you never know.
  mkdir -p ${GRUBDIR}

  # Generate grub.cfg header:
  cat <<EOT > ${GRUBDIR}/grub.cfg
set default="0"
set timeout="30"
set hidden_timeout_quiet=false

menuentry "Detect/boot any installed operating system" {
  configfile "/EFI/BOOT/osdetect.cfg"
}

EOT

  for KBD in $(cat ${LIVE_TOOLDIR}/languages |grep -Ev "(^ *#|^$)" |cut -d, -f3)
  do
    LANDSC=$(cat ${LIVE_TOOLDIR}/languages |grep ",$KBD," |cut -d, -f2)
    LANTZ=$(cat ${LIVE_TOOLDIR}/languages |grep ",$KBD," |cut -d, -f4)
    LANLOC=$(cat ${LIVE_TOOLDIR}/languages |grep ",$KBD," |cut -d, -f5)
    cat <<EOT >> ${GRUBDIR}/grub.cfg
menuentry "Slackware${DIRSUFFIX} ${SL_VERSION} Live ($LANDSC)" {
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 tz=${LANTZ} locale=${LANLOC} kbd=${KBD}
  initrd /boot/initrd.img
}

EOT
  done

}

# ---------------------------------------------------------------------------
# Action!
# ---------------------------------------------------------------------------

while getopts "d:efhm:r:s:t:vHR:" Option
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
        echo "  slackware-<RELEASE> or slackware64-<RELEASE>"
        echo "Current value of SL_REPO : $SL_REPO"
        echo ""
        echo "The script's parameters are:"
        echo " -h                 This help."
        echo " -d desktoptype     SLACKWARE (full Slack), KDE4 (basic KDE4),"
        echo "                    XFCE (basic XFCE) or PLASMA5 (full Plasma5)"
        echo " -e                 Use ISO boot-load-size of 32 for computers"
        echo "                    where the ISO won't boot otherwise."
        echo " -f                 Forced re-generation of all squashfs modules,"
        echo "                    custom configurations and new initrd.img."
        echo " -m pkglst[,pkglst] Add modules defined by pkglists/<pkglst>,..."
        echo " -r series[,series] Refresh only one or a few package series."
        echo " -s slackrepo_dir   Directory containing Slackware repository."
        echo " -t <doc|mandoc>    Trim the ISO for size (remove man and/or doc)"
        echo " -v                 Show debug/error output."
        echo " -H <hostname>      Hostname of the Live OS (default: $LIVE_HOSTNAME)"
        echo " -R <runlevel>      Runlevel to start with (default: $RUNLEVEL)"
        exit
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

# Do we have a local Slackware repository?
if [ ! -d ${SL_REPO} ]; then
  echo "-- Slackware repository root '${SL_REPO}' does not exist! Exiting."
  exit 1
fi

# Are all the required add-on tools present?
PROG_MISSING=""
for PROGN in mksquashfs unsquashfs syslinux mkisofs installpkg upgradepkg keytab-lilo ; do
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
          *) echo "** Unsupported configuration '$LIVEDE'"; exit 1 ;;
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

  if [ "$FORCE" = "YES" -o $(echo ${REFRESH} |grep -wq ${SPS} ; echo $?) -eq 0 -o ! -f ${LIVE_MOD_SYS}/${MNUM}-slackware_${SPS}-${SL_VERSION}-${SL_ARCH}.sxz ]; then

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
      KVER=$(echo ${INSTDIR}/var/log/packages/kernel-generic-[0-9]* |rev |cut -d- -f3 |rev)
      if [ -z "$KVER" ]; then
        echo "-- Could not find installed kernel in '${INSTDIR}'! Exiting."
        exit 1
      else
        # Move the content of the /boot directory out of the minimal system,
        # this will be joined again using overlay:
        rm -rf ${LIVE_BOOT}/boot
        mv ${INSTDIR}/boot ${LIVE_BOOT}/
        # Squash the boot files into a module as a safeguard:
        mksquashfs ${LIVE_BOOT} ${LIVE_MOD_SYS}/0000-slackware_boot-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M
      fi

    fi

    # Squash the installed package series into a module:
    mksquashfs ${INSTDIR} ${LIVE_MOD_SYS}/${MNUM}-slackware_${SPS}-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M
    rm -rf ${INSTDIR}/*

    # End result: we have our .sxz file and the INSTDIR is empty again,
    # Next step is to loop-mount the squashfs file onto INSTDIR.

  elif [ "$SPS" = "a" -o "$SPS" = "min" ]; then

    # We need to do a bit more if we skipped creation of 'a' or 'min' module:
    # Extract the content of the /boot directory out of the boot module,
    # else we don't have a /boot ready when we create the ISO.
    # We can not just loop-mount it because we need to write into /boot later:
    rm -rf ${LIVE_BOOT}/boot
    unsquashfs -dest ${LIVE_BOOT}/boottemp ${LIVE_MOD_SYS}/0000-slackware_boot-${SL_VERSION}-${SL_ARCH}.sxz
    mv ${LIVE_BOOT}/boottemp/* ${LIVE_BOOT}/
    rmdir ${LIVE_BOOT}/boottemp

  fi

  # Add the package series tree to the readonly lowerdirs for the overlay:
  RODIRS="${INSTDIR}:${RODIRS}"

  # Mount the modules for use in the final assembly of the ISO:
  mount -t squashfs -o loop ${LIVE_MOD_SYS}/${MNUM}-slackware_${SPS}-${SL_VERSION}-${SL_ARCH}.sxz ${INSTDIR}

done
done

# ----------------------------------------------------------------------------
# Modules for all package series are created and loop-mounted.
# Next: system configuration.
# ----------------------------------------------------------------------------

# Configuration mudule will always be created from scratch:
INSTDIR=${LIVE_WORK}/zzzconf_$$
mkdir -p ${INSTDIR}

echo "-- Configuring the base system."
umount ${LIVE_ROOTDIR} 2>${DBGOUT} || true
mount -t overlay -o lowerdir=${RODIRS},upperdir=${INSTDIR},workdir=${LIVE_OVLDIR} overlay ${LIVE_ROOTDIR}

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

# Reduce the number of local consoles, two should be enough:
sed -i -e '/^c3\|^c4\|^c5\|^c6/s/^/# /' ${LIVE_ROOTDIR}/etc/inittab

# Prevent loop devices (xzm modules) from appearing in filemanagers:
mkdir -p ${LIVE_ROOTDIR}/etc/udev/rules.d
cat <<EOL > ${LIVE_ROOTDIR}/etc/udev/rules.d/11-local.rules
# Prevent loop devices (mounted xzm modules) from appearing in
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
MIRRORPLUS['restricted']=http://taper.alienbase.nl/mirrors/people/alien/restricted_sbrepos/current/x86_64/
MIRRORPLUS['alienbob']=http://taper.alienbase.nl/mirrors/people/alien/sbrepos/current/x86_64/
MIRRORPLUS['ktown_testing']=http://taper.alienbase.nl/mirrors/alien-kde/current/testing/x86_64/

EOPL
fi

/usr/sbin/slackpkg -batch=on update gpg
/usr/sbin/slackpkg -batch=on update

EOSL

echo "-- Configuring the X base system."
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

# The Xscreensaver should show a blank screen only, to prevent errors about
# missing modules:
echo "mode:           blank" > ${LIVE_ROOTDIR}/home/live/.xscreensaver

# Add our scripts to the Live OS:
mkdir -p  ${LIVE_ROOTDIR}/usr/local/sbin
install -m0755 ${LIVE_TOOLDIR}/makemod ${LIVE_TOOLDIR}/iso2usb.sh  ${LIVE_ROOTDIR}/usr/local/sbin/

echo "-- Configuring XFCE."
# Prepare some XFCE defaults for the 'live' user and any new users.
# (don't show icons on the desktop for irrelevant stuff):
mkdir -p ${LIVE_ROOTDIR}/etc/skel/
tar -xf ${LIVE_TOOLDIR}/skel/skel.txz -C ${LIVE_ROOTDIR}/etc/skel/

echo "-- Configuring KDE4."
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

if [ "$LIVEDE" = "PLASMA5" ]; then

  echo "-- Configuring PLASMA5."
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

fi # End LIVEDE = PLASMA5

# Give the live user a copy of our skeleton configuration:
cd ${LIVE_ROOTDIR}/etc/skel/
  find . -exec cp -a --parents "{}" ${LIVE_ROOTDIR}/home/live/ \;
cd - 1>/dev/null

# Make sure that user 'live' owns her own files:
chroot ${LIVE_ROOTDIR} chown -R live:users home/live

echo "-- Tweaking system startup."

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
else
  ln -sf xinitrc.xfce ${LIVE_ROOTDIR}/etc/X11/xinit/xinitrc
fi

# Configure the default runlevel:
sed -i ${LIVE_ROOTDIR}/etc/inittab -e "s/\(id:\).\(:initdefault:\)/\1${RUNLEVEL}\2/"

# Disable unneeded services:
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.acpid ] && chmod -x ${LIVE_ROOTDIR}/etc/rc.d/rc.acpid
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.pcmcia ] && chmod -x ${LIVE_ROOTDIR}/etc/rc.d/rc.pcmcia
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.yp ] && chmod -x ${LIVE_ROOTDIR}/etc/rc.d/rc.yp

# But enable NFS client support:
[ -f ${LIVE_ROOTDIR}/etc/rc.d/rc.rpc ] && chmod +x ${LIVE_ROOTDIR}/etc/rc.d/rc.rpc

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

chroot "${LIVE_ROOTDIR}" /bin/bash <<EOCR
# Update the desktop database:
if [ -x usr/bin/update-desktop-database ]; then
  /usr/bin/update-desktop-database usr/share/applications > /dev/null 2>${DBGOUT}
fi

# Update hicolor theme cache:
if [ -d usr/share/icons/hicolor ]; then
  if [ -x /usr/bin/gtk-update-icon-cache ]; then
    /usr/bin/gtk-update-icon-cache -f -t usr/share/icons/hicolor 1>/dev/null 2>${DBGOUT}
  fi
fi

# Update the mime database:
if [ -x usr/bin/update-mime-database ]; then
  /usr/bin/update-mime-database usr/share/mime >/dev/null 2>${DBGOUT}
fi

# Font configuration:
if [ -x usr/bin/fc-cache ]; then
  for fontdir in 100dpi 75dpi OTF Speedo TTF Type1 cyrillic ; do
    if [ -d usr/share/fonts/$fontdir ]; then
      mkfontscale /usr/share/fonts/$fontdir 1>/dev/null 2>${DBGOUT}
      mkfontdir /usr/share/fonts/$fontdir 1>/dev/null 2>${DBGOUT}
    fi
  done
  if [ -d usr/share/fonts/misc ]; then
    mkfontscale /usr/share/fonts/misc  1>/dev/null 2>${DBGOUT}
    mkfontdir -e /usr/share/fonts/encodings -e /usr/share/fonts/encodings/large /usr/share/fonts/misc 1>/dev/null 2>${DBGOUT}
  fi
  /usr/bin/fc-cache -f 1>/dev/null 2>${DBGOUT}
fi

if [ -x usr/bin/update-gtk-immodules ]; then
  /usr/bin/update-gtk-immodules
fi
if [ -x usr/bin/update-gdk-pixbuf-loaders ]; then
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

if [ -x /usr/sbin/nvidia-switch ]; then
  if [ -f /usr/lib${DIRSUFFIX}/xorg/modules/extensions/libglx.so.*-nvidia -a -f /usr/lib${DIRSUFFIX}/xorg/modules/drivers/nvidia_drv.so ]; then
    # The nvidia kernel module needs to ne announced to the kernel.
    # This costs a few seconds in additional boot-up time unfortunately:
    /sbin/depmod -a
    echo "-- Installing binary Nvidia drivers:  /usr/sbin/nvidia-switch --install"
    /usr/sbin/nvidia-switch --install
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
mksquashfs ${INSTDIR} ${LIVE_MOD_SYS}/0099-slackware_zzzconf-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M
rm -rf ${INSTDIR}/*

# End result: we have our .sxz file and the INSTDIR is empty again,
# Next step is to loop-mount the squashfs file onto INSTDIR.

# Add the system configuration tree to the readonly lowerdirs for the overlay:
RODIRS="${INSTDIR}:${RODIRS}"

# Mount the module for use in the final assembly of the ISO:
mount -t squashfs -o loop ${LIVE_MOD_SYS}/0099-slackware_zzzconf-${SL_VERSION}-${SL_ARCH}.sxz ${INSTDIR}

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
KVER=$(ls ${LIVE_ROOTDIR}/var/log/packages/kernel*modules* |head -1 |rev | cut -d- -f3 |rev)

# Create an initrd for the generic kernel, using a modified init script:
echo "-- Creating initrd for kernel-generic $KVER ..."
chroot ${LIVE_ROOTDIR} /sbin/mkinitrd -c -l us -o /boot/initrd_${KVER}.gz -k ${KVER} -m ${KMODS} 1>${DBGOUT} 2>${DBGOUT}
cat $LIVE_TOOLDIR/liveinit | sed \
  -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
  -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
  -e "s/@PERSISTENCE@/$PERSISTENCE/g" \
  -e "s/@DARKSTAR@/$LIVE_HOSTNAME/g" \
  > ${LIVE_ROOTDIR}/boot/initrd-tree/init
chroot ${LIVE_ROOTDIR} /sbin/mkinitrd 1>/dev/null 2>${DBGOUT}
rm -rf ${LIVE_ROOTDIR}/boot/initrd-tree

# ... and cleanup these mounts again:
umount ${LIVE_ROOTDIR}/{proc,sys,dev} || true
umount ${LIVE_ROOTDIR} || true
# Paranoia:
[ ! -z "${LIVE_BOOT}" ] && rm -rf ${LIVE_BOOT}/{etc,tmp,usr,var} 1>${DBGOUT} 2>${DBGOUT}
# Squash the boot directory into its own module:
mksquashfs ${LIVE_BOOT} ${LIVE_MOD_SYS}/0000-slackware_boot-${SL_VERSION}-${SL_ARCH}.sxz -noappend -comp ${SXZ_COMP} -b 1M

# Copy kernel files and tweak the syslinux configuration:
# Note to self: syslinux does not 'see' files unless they are DOS 8.3 names?
rm -rf ${LIVE_STAGING}/boot
mkdir -p ${LIVE_STAGING}/boot
cp -a ${LIVE_BOOT}/boot/vmlinuz-generic-$KVER ${LIVE_STAGING}/boot/generic
cp -a ${LIVE_BOOT}/boot/initrd_${KVER}.gz ${LIVE_STAGING}/boot/initrd.img
cp -a ${LIVE_TOOLDIR}/syslinux ${LIVE_STAGING}/boot/
# Make use of proper console font if we have it available:
if [ -f /usr/share/kbd/consolefonts/${CONSFONT}.gz ]; then
  gunzip -cd /usr/share/kbd/consolefonts/${CONSFONT}.gz > ${LIVE_STAGING}/boot/syslinux/${CONSFONT}
elif [ ! -f ${LIVE_STAGING}/boot/syslinux/${CONSFONT} ]; then
  sed -i -e "s/^font .*/#&/" ${LIVE_STAGING}/boot/syslinux/menu/*menu*.cfg
fi

# Copy the UEFI boot directory structure:
cp -a ${LIVE_TOOLDIR}/EFI ${LIVE_STAGING}/

# The grub-embedded.cfg in the bootx64.efi looks for this file:
touch ${LIVE_STAGING}/EFI/BOOT/${MARKER}
touch ${LIVE_STAGING}/${LIVEMAIN}/${MARKER}

# Generate the UEFI grub boot image if needed:
if [ ! -f ${LIVE_STAGING}/EFI/BOOT/bootx64.efi -o ! -f ${LIVE_STAGING}/boot/syslinux/efiboot.img ]; then
  ( cd ${LIVE_STAGING}/EFI/BOOT
    sed -i -e "s/SLACKWARELIVE/${MARKER}/g" grub-embedded.cfg
    sh make-grub.sh
  )
fi

# Generate the grub configuration for UEFI boot:
gen_uefimenu ${LIVE_STAGING}/EFI/BOOT

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
      -e "s/@KVER@/$KVER/g" \
      -e "s/@LIVEMAIN@/$LIVEMAIN/g" \
      -e "s/@MEDIALABEL@/$MEDIALABEL/g" \
      -e "s/@LIVEDE@/$(echo $LIVEDE |sed 's/BASE//')/g" \
      -e "s/@SL_VERSION@/$SL_VERSION/g"
  fi
done
mv ${LIVE_STAGING}/boot/syslinux/memtest ${LIVE_STAGING}/boot/

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

if [ "$LIVEDE" != "XFCE" -a -f ${LIVE_TOOLDIR}/graphics/*.sxz ]; then
  # KDE/PLASMA etc will profit; add custom (proprietary) graphics drivers:
  echo "-- Adding binary GPU drivers."
  cp ${LIVE_TOOLDIR}/graphics/*.sxz ${LIVE_MOD_OPT}/
fi

# Directory for rootcopy files (everything placed here will be copied
# verbatim into the overlay root):
mkdir -p ${LIVE_STAGING}/rootcopy

# Create an ISO file from the directories found below ${LIVE_STAGING}:
cd ${LIVE_STAGING}
mkisofs -o ${OUTPUT}/slackware${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso \
  -R -J \
  -hide-rr-moved \
  -v -d -N \
  -no-emul-boot -boot-load-size ${BOOTLOADSIZE} -boot-info-table \
  -sort boot/syslinux/iso.sort \
  -b boot/syslinux/isolinux.bin \
  -c boot/syslinux/isolinux.boot \
  -eltorito-alt-boot -no-emul-boot -eltorito-platform 0xEF \
  -eltorito-boot boot/syslinux/efiboot.img \
  -preparer "Built for Slackware${DIRSUFFIX}-Live by ${BUILDER}" \
  -publisher "The Slackware Linux Project - http://www.slackware.com/" \
  -A "Slackware Live ${SL_VERSION} for ${ARCH}" \
  -V "${MEDIALABEL}" \
  -x ./$(basename ${LIVE_WORK}) \
  -x ./${LIVEMAIN}/bootinst \
  -x boot/syslinux/testing \
  -x rootcopy \
  .

# This copy is no longer needed:
rm -rf ./boot
cd -
SIZEISO=$(stat --printf %s ${OUTPUT}/slackware${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso)
# We want at most 1024 cylinders for old BIOS; also we want no more than
# 63 sectors, no more than 255 heads, which leads to a cut-over size:.
# 64 (heads) *32 (sectors) *1024 (cylinders) *512 (bytes) = 1073741824 bytes.
# However, for sizes > 8422686720 compatibility will be out the window anyway.
if [ $SIZEISO -gt 8422686720 ]; then
  isohybrid -u ${OUTPUT}/slackware${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso
else
  if [ $SIZEISO -gt 1073741824 ]; then
    # No more than 63 sectors, no more than 255 heads.
    SECTORS=63
    HEADS=$(( ($SIZEISO/1024/63/512) + 2 ))
  else
    #  The default values for isohybrid that give a size of 1073741824 bytes.
    SECTORS=32
    HEADS=64
  fi
  isohybrid -s $SECTORS -h $HEADS -u ${OUTPUT}/slackware${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso
fi
md5sum ${OUTPUT}/slackware${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso \
  > ${OUTPUT}/slackware${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso.md5
echo "-- Live ISO image created:"
ls -l ${OUTPUT}/slackware${DIRSUFFIX}-live${ISOTAG}-${SL_VERSION}.iso*

# Clean out the mounts etc:
cleanup

