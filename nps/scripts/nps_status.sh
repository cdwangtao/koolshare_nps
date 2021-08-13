#! /bin/sh

source $KSROOT/scripts/base.sh
nps_version=$(dbus get nps_client_version)
nps_pid=$(pidof nps)
LOGTIME=$(TZ=UTC-8 date -R "+%Y-%m-%d %H:%M:%S")
if [ -n "$nps_pid" ];then
	http_response "【$LOGTIME】nps ${nps_version} 进程运行正常！（PID：$nps_pid）"
else
	http_response "【$LOGTIME】nps ${nps_version} 进程未运行！"
fi
