#
# GRUB menu template for Slackware Live Edition
#
set grubdir="($root)/EFI/BOOT"
export grubdir

set default=0
set timeout=20

# Slackware Live defaults, can be changed in submenus:
if [ -z "$sl_kbd" ]; then
  set sl_kbd="us"
  export sl_kbd
fi
if [ -z "$sl_tz" ]; then
  set sl_tz="US/Pacific"
  export sl_tz
fi
if [ -z "$sl_lang" ]; then
  set sl_lang="us american"
  export sl_lang
fi
if [ -z "$sl_locale" ]; then
  set sl_locale="en_US.utf8"
  export sl_locale
fi

# Determine whether we can show a graphical themed menu:
insmod font
if loadfont $grubdir/theme/dejavusansmono12.pf2 ; then
  loadfont $grubdir/theme/dejavusansmono10.pf2
  loadfont $grubdir/theme/dejavusansmono5.pf2
  set gfxmode=auto,640x480
  export gfxmode
  # (U)EFI requirement: must support all_video:
  insmod all_video
  insmod gfxterm
  insmod gfxmenu
  terminal_output gfxterm
  insmod gettext
  insmod png
  set theme=$grubdir/theme/liveslak.txt
  export theme
fi

menuentry "Start Slackware@DIRSUFFIX@ @SL_VERSION@ @LIVEDE@ Live @VERSION@ ($sl_lang)" --hotkey b {
  linux ($root)/boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=$sl_kbd tz=$sl_tz locale=$sl_locale
  initrd ($root)/boot/initrd.img
}

submenu "Non-US Keyboard selection" --hotkey k {
  configfile $grubdir/kbd.cfg
}

submenu "Non-US Language selection" --hotkey l {
  configfile $grubdir/lang.cfg
}

submenu "Non-US Timezone selection" --hotkey t {
  configfile $grubdir/tz.cfg
}

menuentry "Memory test with memtest86+" {
  linux ($root)/boot/memtest
}

menuentry "Help on boot parameters" --hotkey h { 
  set pager=1 
  cat $grubdir/help.txt 
  unset pager 
} 

