#!/bin/sh
export KSROOT=/koolshare
source $KSROOT/scripts/base.sh

# 停止服务
sh /koolshare/scripts/nps_config.sh stop >/dev/null 2>&1

rm -f /koolshare/bin/nps
find /koolshare/init.d/ -name "*nps*" | xargs rm -rf
rm -rf /koolshare/res/icon-nps.png
rm -rf /koolshare/scripts/nps_*.sh
rm -rf /koolshare/webs/Module_nps.asp
rm -f /koolshare/scripts/uninstall_nps.sh
# rm -f /koolshare/configs/nps.ini

values=$(dbus list nps | cut -d "=" -f 1)
for value in $values
do
	dbus remove $value
done