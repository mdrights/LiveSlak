# Firejail profile for Tencent QQ.
# Persistent local customizations
include qq.local
# This profile is based (forked) on:
# include default.profile

# generic gui profile
# depending on your usage, you can enable some of the commands below:

blacklist /opt
read-only /etc

include disable-common.inc
include disable-devel.inc
include disable-exec.inc
include disable-interpreters.inc
include disable-passwdmgr.inc
include disable-programs.inc
include disable-write-mnt.inc
include disable-xdg.inc

# include whitelist-common.inc
# include whitelist-usr-share-common.inc
include whitelist-runuser-common.inc
# include whitelist-var-common.inc

# apparmor
caps.drop all
# ipc-namespace
machine-id
# net none
netfilter
no3d
nodvd
nogroups
nonewprivs
noroot
nosound
notv
nou2f
novideo
protocol unix,inet,inet6
seccomp
shell none
# tracelog

disable-mnt
private
# private-bin program
# private-cache
# private-dev
# see /usr/share/doc/firejail/profile.template for more common private-etc paths.
# private-etc alternatives,fonts,machine-id
# private-lib
# private-opt none
# private-tmp

dbus-user filter
dbus-user.talk org.freedesktop.portal.Fcitx
#dbus-user none
dbus-system none

memory-deny-write-execute
#read-only ${HOME}

