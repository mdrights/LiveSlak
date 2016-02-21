prompt 0
timeout 300
ui vesamenu.c32
default live
font @CONSFONT@
menu background swlogov.png
menu title Slackware@DIRSUFFIX@-@SL_VERSION@ Live @VERSION@
menu clear
f2 f2.txt #00000000
f3 f3.txt #00000000
f4 f4.txt #00000000

menu hshift 1
menu vshift 9
menu width 45
menu margin 1
menu rows 10
menu helpmsgrow 14
menu helpmsgendrow 18
menu cmdlinerow 18
menu tabmsgrow 19
menu timeoutrow 20

menu color screen       37;40      #00000000 #00000000 none
menu color border       34;40      #00000000 #00000000 none
menu color title        1;36;44    #ffb9556b #30002d1f none
menu color unsel        37;44      #ff354172 #007591ff none
menu color hotkey       1;37;44    #ffad37b7 #00000000 none
menu color sel          7;37;40    #ffffffff #00000000 none
menu color hotsel       1;7;37;40  #ffe649f3 #00000000 none
menu color scrollbar    30;44      #00000000 #00000000 none
menu color tabmsg       31;40      #ffA32222 #00000000 none
menu color cmdmark      1;36;40    #ffff0000 #00000000 none
menu color cmdline      37;40      #ffffffff #ff000000 none
menu color pwdborder    30;47      #ffff0000 #00000000 std
menu color pwdheader    31;47      #ffff0000 #00000000 std
menu color pwdentry     30;47      #ffff0000 #00000000 std
menu color timeout_msg  37;40      #ff809aef #00000000 none
menu color timeout      1;37;40    #ffb72f9f #00000000 none
menu color help         37;40      #ff354172 #00000000 none

label live
  menu label Start @LIVEDE@ Live
  menu default
  kernel /boot/generic
  append initrd=/boot/initrd.img load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=@KBD@
  text help
    Slackware@DIRSUFFIX@-@SL_VERSION@, kernel @KVER@.
    Add 'load=nvidia' to the commandline
    if you have a recent NVIDIA card.
  endtext

menu begin kbd
  menu title Non-US Keyboard selection
  label Previous
  menu label Previous Menu
  menu exit
  menu separator
  menu include menu/kbd.cfg
menu end

menu begin language
  menu title Non-US Language selection
  label Previous
  menu label Previous Menu
  menu exit
  menu separator
  menu include menu/lang_@LANG@.cfg
menu end

label memtest
menu label Memory test with memtest86+
  kernel /boot/memtest

label localboot
menu label Boot from local drive
  localboot -1
