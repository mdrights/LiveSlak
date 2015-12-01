set default="0"
set timeout="30"
set hidden_timeout_quiet=false

menuentry "Detect/boot any installed operating system" {
  configfile "/EFI/BOOT/osdetect.cfg"
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (US English)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 tz=US/Pacific locale=en_US.utf8 kbd=@KBD@
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Dutch)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=nl tz=Europe/Amsterdam locale=nl_NL.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (French)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=fr tz=Europe/Paris locale=fr_FR.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (German)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=de tz=Europe/Berlin locale=de_DE.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Greek)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=us tz=Europe/Athens locale=el_GR.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Norwegian)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=no-latin1 tz=Europe/Oslo locale=nb_NO.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Polish)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=pl tz=Europe/Warsaw locale=pl_PL.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Portuguese - Brazil)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=br-abnt2 tz=America/Sao_Paulo locale=pt_BR.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Portuguese - Portugal)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=pt-latin1 tz=Europe/Lisbon locale=pt_PT.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Russian)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=ruwin_cplk-UTF-8 tz=Europe/Moscow locale=ru_RU.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware64 14.2 live in Spanish (Latin America)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=la-latin1 tz=America/Costa_Rica locale=es_CR.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Swedish)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=sv-latin1 tz=Europe/Stockholm locale=sv_SE.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Turkish)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=trq tz=Europe/Istanbul locale=tr_TR.utf8
  initrd /boot/initrd.img
}

menuentry "Slackware@DIRSUFFIX@ @SL_VERSION@ Live (Ukrainian)" {
  echo "Loading kernel and initrd.  Please wait..."
  linux /boot/generic load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 kbd=ua tz=Europe/Kiev locale=uk_UA.utf8
  initrd /boot/initrd.img
}
