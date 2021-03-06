#!/bin/sh
source /koolshare/scripts/base.sh
eval $(dbus export nps_)
# nps conf的备份目录 固定目录[/etc/nps/conf]
CONF_BAKALL_DIR=/koolshare/res/nps/conf
CONF_BAK_DIR=/koolshare/configs/nps
CONF_REAL_DIR=/etc/nps/conf
# nps web的备份目录  固定目录[/etc/nps/web]
WEB_BAK_DIR=/koolshare/res/nps/web
WEB_REAL_DIR=/etc/nps/web
LOG_FILE=/tmp/upload/nps_log.txt
LOCK_FILE=/var/lock/nps.lock
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
# true > $LOG_FILE

# 设置 锁?
set_lock() {
	exec 1000>"$LOCK_FILE"
	flock -x 1000
}
# 解锁?
unset_lock() {
	flock -u 1000
	rm -rf "$LOCK_FILE"
}
# 时间同步
sync_ntp(){
	# START_TIME=$(date +%Y/%m/%d-%X)
	echo_date "尝试从ntp服务器：ntp1.aliyun.com 同步时间..."
	ntpclient -h ntp1.aliyun.com -i3 -l -s >/tmp/ali_ntp.txt 2>&1
	SYNC_TIME=$(cat /tmp/ali_ntp.txt|grep -E "\[ntpclient\]"|grep -Eo "[0-9]+"|head -n1)
	if [ -n "${SYNC_TIME}" ];then
		SYNC_TIME=$(date +%Y/%m/%d-%X @${SYNC_TIME})
		echo_date "完成！时间同步为：${SYNC_TIME}"
	else
		echo_date "时间同步失败，跳过！"
	fi
}
# 添加nat-start触发
fun_nat_start(){
	if [ "${nps_enable}" == "1" ];then
		if [ ! -L "/koolshare/init.d/N95nps.sh" ];then
			echo_date "添加nat-start触发..."
			ln -sf /koolshare/scripts/nps_config.sh /koolshare/init.d/N95nps.sh
		fi
	else
		if [ -L "/koolshare/init.d/N95nps.sh" ];then
			echo_date "删除nat-start触发..."
			rm -rf /koolshare/init.d/N95nps.sh >/dev/null 2>&1
		fi
	fi
}
# 启动
onstart() {
	# 插件开启的时候同步一次时间
	if [ "${nps_enable}" == "1" -a -n "$(which ntpclient)" ];then
		sync_ntp
	fi

	# 关闭nps进程
	if [ -n "$(pidof nps)" ];then
		echo_date "关闭当前nps进程..."
		killall nps >/dev/null 2>&1
	fi
	
	# 插件安装的时候移除nps_client_version，插件第一次运行的时候设置一次版本号即可
	if [ -z "${nps_client_version}" ];then
		dbus set nps_client_version=$(/koolshare/bin/nps --version)
		nps_client_version=$(/koolshare/bin/nps --version)
	fi
	echo_date "当前插件nps主程序版本号：${nps_client_version}"

	# 判断 nps 配置的备份目录是否存在 不存在则创建
  if [ ! -d "${CONF_BAK_DIR}/" ];then
    mkdir -p "${CONF_BAK_DIR}/"
  fi
  # 生成 nps 配置文件
	echo_date "生成nps配置文件到 ${CONF_BAK_DIR}/nps.conf"
	cat >"${CONF_BAK_DIR}/nps.conf" <<-EOF
appname = nps
#Boot mode(dev|pro)
runmode = pro

#HTTP(S) proxy port, no startup if empty
http_proxy_ip=0.0.0.0
http_proxy_port=${nps_common_http_proxy_port}
https_proxy_port=${nps_common_https_proxy_port}
https_just_proxy=true
#default https certificate setting
https_default_cert_file=${nps_common_https_default_cert_file}
https_default_key_file=${nps_common_https_default_key_file}

##bridge
bridge_type=tcp
bridge_port=${nps_common_bridge_port}
bridge_ip=0.0.0.0

# Public password, which clients can use to connect to the server
# After the connection, the server will be able to open relevant ports and parse related domain names according to its own configuration file.
public_vkey=123

#Traffic data persistence interval(minute)
#Ignorance means no persistence
#flow_store_interval=1

# log level LevelEmergency->0  LevelAlert->1 LevelCritical->2 LevelError->3 LevelWarning->4 LevelNotice->5 LevelInformational->6 LevelDebug->7
log_level=7
#log_path=nps.log

#Whether to restrict IP access, true or false or ignore
#ip_limit=true

#p2p
#p2p_ip=127.0.0.1
#p2p_port=6000

#web
web_host=a.o.com
web_username=${nps_common_web_username}
web_password=${nps_common_web_password}
web_port=${nps_common_web_port}
web_ip=0.0.0.0
web_base_url=${nps_common_web_base_url}
web_open_ssl=${nps_common_web_open_ssl}
web_cert_file=${nps_common_web_cert_file}
web_key_file=${nps_common_web_key_file}
# if web under proxy use sub path. like http://host/nps need this.
#web_base_url=/nps

#Web API unauthenticated IP address(the len of auth_crypt_key must be 16)
#Remove comments if needed
#auth_key=test
auth_crypt_key =1234567812345678

#allow_ports=9001-9009,10001,11000-12000
allow_ports=${nps_common_allow_ports}

#Web management multi-user login
allow_user_login=${nps_common_allow_user_login}
allow_user_register=${nps_common_allow_user_register}
allow_user_change_username=false

#extension
allow_flow_limit=false
allow_rate_limit=false
allow_tunnel_num_limit=false
allow_local_proxy=false
allow_connection_num_limit=false
allow_multi_ip=false
system_info_display=false

#cache
http_cache=false
http_cache_length=100

#get origin ip
http_add_origin_header=false

#pprof debug options
#pprof_ip=0.0.0.0
#pprof_port=9999

#client disconnect timeout
disconnect_timeout=60	
	EOF
  # 拷贝1.配置文件(conf)
  if [ ! -d "${CONF_REAL_DIR}/" ];then
    echo_date "nps固定的配置目录(conf)[${CONF_REAL_DIR}/]不存在, 开始创建[${CONF_REAL_DIR}/]目录，并拷贝[${CONF_BAKALL_DIR}/*]到[${CONF_REAL_DIR}/]"
    mkdir -p ${CONF_REAL_DIR}/
    cp -rf ${CONF_BAKALL_DIR}/* ${CONF_REAL_DIR}/
	  # cp -rf /koolshare/res/nps/conf/ /etc/nps/
  fi
  # 拷贝2.资源文件(web)
  if [ ! -d "${WEB_REAL_DIR}/" ];then
    echo_data "nps固定的配置目录(web)[${WEB_REAL_DIR}/]不存在, 开始创建[${WEB_REAL_DIR}/]目录，并拷贝[${WEB_BAK_DIR}/*]到[${WEB_REAL_DIR}/]"
    mkdir -p ${WEB_REAL_DIR}/
    cp -rf ${WEB_BAK_DIR}/*  ${WEB_REAL_DIR}/
	  # cp -rf /koolshare/res/nps/web/ /etc/nps/
  fi
  if [ ! -f "${WEB_REAL_DIR}/views/index/index.html" ];then
    echo_data "nps固定的配置文件(web)[${WEB_BAK_DIR}/views/index/index.html]不存在，拷贝[${WEB_BAK_DIR}/*]到[${WEB_REAL_DIR}/]"
    cp -rf ${WEB_BAK_DIR}/* ${WEB_REAL_DIR}/
	fi
  # wt增强1.还原配置文件 参数1(是否比较时间拷贝文件 1:比较时间 0:不比较)
  on_restore_conf 0
  # 4个ssl文件默认值
  if [ ! -f "${CONF_BAK_DIR}/https_default_key_file.key" ];then
    cp -rf ${CONF_BAKALL_DIR}/server.key ${CONF_BAK_DIR}/https_default_key_file.key
	fi
  if [ ! -f "${CONF_BAK_DIR}/https_default_cert_file.pem" ];then
    cp -rf ${CONF_BAKALL_DIR}/server.pem ${CONF_BAK_DIR}/https_default_cert_file.pem
	fi
  if [ ! -f "${CONF_BAK_DIR}/web_key_file.key" ];then
    cp -rf ${CONF_BAKALL_DIR}/server.key ${CONF_BAK_DIR}/web_key_file.key
	fi
  if [ ! -f "${CONF_BAK_DIR}/web_cert_file.pem" ];then
    cp -rf ${CONF_BAKALL_DIR}/server.pem ${CONF_BAK_DIR}/web_cert_file.pem
	fi

	# 定时任务 1
	if [ "${nps_common_cron_time}" == "0" ]; then
		cru d nps_monitor >/dev/null 2>&1
	else
		if [ "${nps_common_cron_hour_min}" == "min" ]; then
			echo_date "设置定时任务：每隔${nps_common_cron_time}分钟重启nps服务..."
			cru a nps_monitor "*/"${nps_common_cron_time}" * * * * /bin/sh /koolshare/scripts/nps_config.sh restart"
		elif [ "${nps_common_cron_hour_min}" == "hour" ]; then
			echo_date "设置定时任务：每隔${nps_common_cron_time}小时重启nps服务..."
			cru a nps_monitor "0 */"${nps_common_cron_time}" * * * /bin/sh /koolshare/scripts/nps_config.sh restart"
		fi
		echo_date "定时任务设置完成！"
	fi
  # 定时任务 2 定时备份配置文件
	if [ "${nps_common_cron2_time}" == "0" ]; then
		cru d nps_monitor >/dev/null 2>&1
	else
		if [ "${nps_common_cron2_hour_min}" == "min" ]; then
			echo_date "设置定时任务：每隔${nps_common_cron2_time}分钟备份一次nps配置文件(如果配置文件有变化)..."
			cru a nps_monitor "*/"${nps_common_cron2_time}" * * * * /bin/sh /koolshare/scripts/nps_config.sh backconf"
		elif [ "${nps_common_cron2_hour_min}" == "hour" ]; then
			echo_date "设置定时任务：每隔${nps_common_cron2_time}小时备份一次nps配置文件(如果配置文件有变化)..."
			cru a nps_monitor "0 */"${nps_common_cron2_time}" * * * /bin/sh /koolshare/scripts/nps_config.sh backconf"
		fi
		echo_date "定时任务设置完成！"
	fi

	# 开启nps
	if [ "$nps_enable" == "1" ]; then
		echo_date "启动nps主程序..."
		export GOGC=40
		# start-stop-daemon -S -q -b -m -p /var/run/nps.pid -x /koolshare/bin/nps -- -c ${CONF_FILE}
		start-stop-daemon -S -q -b -m -p /var/run/nps.pid -x /koolshare/bin/nps

		local npsPID
		local i=10
		until [ -n "$npsPID" ]; do
			i=$(($i - 1))
			npsPID=$(pidof nps)
			if [ "$i" -lt 1 ]; then
				echo_date "nps进程启动失败！"
				echo_date "可能是内存不足造成的，建议使用虚拟内存后重试！"
				close_in_five
			fi
			usleep 250000
		done
		echo_date "nps启动成功，pid：${npsPID}"
		fun_nat_start
		open_port
	else
		stop
	fi
	echo_date "nps插件启动完毕，本窗口将在5s内自动关闭！"
}
# 检查端口
check_port(){
	local prot=$1
	local port=$2
	local open=$(iptables -S -t filter | grep INPUT | grep dport | grep ${prot} | grep ${port})
	if [ -n "${open}" ];then
		echo 0
	else
		echo 1
	fi
}
# 打开端口
open_port(){
	local t_port
	local u_port
	[ "$(check_port tcp ${nps_common_bridge_port})" == "1" ] && iptables -I INPUT -p tcp --dport ${nps_common_bridge_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && t_port="${nps_common_bridge_port}"
	[ "$(check_port tcp ${nps_common_web_port})" == "1" ] && iptables -I INPUT -p tcp --dport ${nps_common_web_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && t_port="${t_port} ${nps_common_web_port}"
	[ "$(check_port tcp ${nps_common_http_proxy_port})" == "1" ] && iptables -I INPUT -p tcp --dport ${nps_common_http_proxy_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && t_port="${t_port} ${nps_common_http_proxy_port}"
	[ "$(check_port tcp ${nps_common_https_proxy_port})" == "1" ] && iptables -I INPUT -p tcp --dport ${nps_common_https_proxy_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && t_port="${t_port} ${nps_common_https_proxy_port}"
	[ "$(check_port udp ${nps_common_bridge_port})" == "1" ] && iptables -I INPUT -p udp --dport ${nps_common_bridge_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && u_port="${nps_common_bridge_port}"
	[ "$(check_port udp ${nps_common_http_proxy_port})" == "1" ] && iptables -I INPUT -p udp --dport ${nps_common_web_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && u_port="${u_port} ${nps_common_web_port}"
	[ "$(check_port udp ${nps_common_http_proxy_port})" == "1" ] && iptables -I INPUT -p udp --dport ${nps_common_http_proxy_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && u_port="${u_port} ${nps_common_http_proxy_port}"
	[ "$(check_port udp ${nps_common_https_proxy_port})" == "1" ] && iptables -I INPUT -p udp --dport ${nps_common_https_proxy_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && u_port="${u_port} ${nps_common_https_proxy_port}"
  # 动态设置 tcp udp
	temp_ports="${nps_common_allow_ports//-/:}"
  IFS="," 
  set -- $temp_ports 
  for temp_port 
  do 
    # echo "$val" 
    [ "$(check_port tcp ${temp_port})" == "1" ] && iptables -I INPUT -p tcp --dport ${temp_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && t_port="${t_port} ${temp_port}"
	  [ "$(check_port udp ${temp_port})" == "1" ] && iptables -I INPUT -p udp --dport ${temp_port} -j ACCEPT >/tmp/ali_ntp.txt 2>&1 && u_port="${u_port} ${temp_port}"
  done
	[ -n "${t_port}" ] && echo_date "开启TCP端口：${t_port}"
	[ -n "${u_port}" ] && echo_date "开启UDP端口：${u_port}"
}
# 关闭端口
close_port(){
	local t_port
	local u_port
	[ "$(check_port tcp ${nps_common_bridge_port})" == "0" ] && iptables -D INPUT -p tcp --dport ${nps_common_bridge_port} -j ACCEPT >/dev/null 2>&1 && t_port="${nps_common_bridge_port}"
	[ "$(check_port tcp ${nps_common_web_port})" == "0" ] && iptables -D INPUT -p tcp --dport ${nps_common_web_port} -j ACCEPT >/dev/null 2>&1 && t_port="${t_port} ${nps_common_web_port}"
	[ "$(check_port tcp ${nps_common_http_proxy_port})" == "0" ] && iptables -D INPUT -p tcp --dport ${nps_common_http_proxy_port} -j ACCEPT >/dev/null 2>&1 && t_port="${t_port} ${nps_common_http_proxy_port}"
	[ "$(check_port tcp ${nps_common_https_proxy_port})" == "0" ] && iptables -D INPUT -p tcp --dport ${nps_common_https_proxy_port} -j ACCEPT >/dev/null 2>&1 && t_port="${t_port} ${nps_common_https_proxy_port}"
	[ "$(check_port udp ${nps_common_bridge_port})" == "0" ] && iptables -D INPUT -p udp --dport ${nps_common_bridge_port} -j ACCEPT >/dev/null 2>&1 && u_port="${nps_common_bridge_port}"
	[ "$(check_port udp ${nps_common_web_port})" == "0" ] && iptables -D INPUT -p udp --dport ${nps_common_web_port} -j ACCEPT >/dev/null 2>&1 && u_port="${u_port} ${nps_common_web_port}"
	[ "$(check_port udp ${nps_common_http_proxy_port})" == "0" ] && iptables -D INPUT -p udp --dport ${nps_common_http_proxy_port} -j ACCEPT >/dev/null 2>&1 && u_port="${u_port} ${nps_common_http_proxy_port}"
	[ "$(check_port udp ${nps_common_https_proxy_port})" == "0" ] && iptables -D INPUT -p udp --dport ${nps_common_https_proxy_port} -j ACCEPT >/dev/null 2>&1 && u_port="${u_port} ${nps_common_https_proxy_port}"
	# 动态设置 tcp udp
	temp_ports="${nps_common_allow_ports//-/:}"
  IFS="," 
  set -- $temp_ports 
  for temp_port 
  do 
    # echo "$val" 
	  [ "$(check_port tcp ${temp_port})" == "0" ] && iptables -D INPUT -p tcp --dport ${temp_port} -j ACCEPT >/dev/null 2>&1 && t_port="${t_port} ${temp_port}"
	  [ "$(check_port udp ${temp_port})" == "0" ] && iptables -D INPUT -p udp --dport ${temp_port} -j ACCEPT >/dev/null 2>&1 && u_port="${u_port} ${temp_port}"
  done
  [ -n "${t_port}" ] && echo_date "关闭TCP端口：${t_port}"
	[ -n "${u_port}" ] && echo_date "关闭UDP端口：${u_port}"
}
# 5秒后关闭
close_in_five() {
	echo_date "插件将在5秒后自动关闭！！"
	local i=5
	while [ $i -ge 0 ]; do
		sleep 1
		echo_date $i
		let i--
	done
	dbus set ss_basic_enable="0"
	disable_ss >/dev/null
	echo_date "插件已关闭！！"
	unset_lock
	exit
}
# 停止
stop() {
  # wt增强2.备份配置文件 参数1(是否比较时间拷贝文件 1:比较时间 0:不比较)
  on_back_conf 1
	# 关闭nps进程
	if [ -n "$(pidof nps)" ];then
		echo_date "停止nps主进程，pid：$(pidof nps)"
		killall nps >/dev/null 2>&1
	fi
  # 删除定时任务1
	if [ -n "$(cru l|grep nps_monitor)" ];then
		echo_date "删除定时任务1..."
		cru d nps_monitor >/dev/null 2>&1
	fi
  # 删除定时任务2
	if [ -n "$(cru l|grep nps_monitor2)" ];then
		echo_date "删除定时任务2..."
		cru d nps_monitor2 >/dev/null 2>&1
	fi
  # 删除开机自启动
	if [ -L "/koolshare/init.d/N95nps.sh" ];then
    echo_date "删除nat触发..."
    rm -rf /koolshare/init.d/N95nps.sh >/dev/null 2>&1
  fi
  # 关闭端口
  close_port
}
# wt增强1.还原配置文件 参数1(是否比较时间拷贝文件 1:比较时间 0:不比较)
on_restore_conf() {
  if [ "${1}" == "1" ]; then
		compareTwoFileTimesAndCopy "${CONF_BAK_DIR}/nps.conf"     "${CONF_REAL_DIR}/nps.conf"     "还原"
    compareTwoFileTimesAndCopy "${CONF_BAK_DIR}/clients.json" "${CONF_REAL_DIR}/clients.json" "还原"
    compareTwoFileTimesAndCopy "${CONF_BAK_DIR}/hosts.json"   "${CONF_REAL_DIR}/hosts.json"   "还原"
    compareTwoFileTimesAndCopy "${CONF_BAK_DIR}/tasks.json"   "${CONF_REAL_DIR}/tasks.json"   "还原"
	else
    echo_date "还原配置文件 nps.conf clients.json hosts.json tasks.json"
		cp -rf "${CONF_BAK_DIR}/nps.conf"     "${CONF_REAL_DIR}/nps.conf"
    cp -rf "${CONF_BAK_DIR}/clients.json" "${CONF_REAL_DIR}/clients.json"
    cp -rf "${CONF_BAK_DIR}/hosts.json"   "${CONF_REAL_DIR}/hosts.json"
    cp -rf "${CONF_BAK_DIR}/tasks.json"   "${CONF_REAL_DIR}/tasks.json"
	fi
}
# wt增强2.备份配置文件 参数1(是否比较时间拷贝文件 1:比较时间 0:不比较)
on_back_conf() {
  if [ "${1}" == "1" ]; then
		compareTwoFileTimesAndCopy "${CONF_REAL_DIR}/nps.conf"     "${CONF_BAK_DIR}/nps.conf"     "备份"
    compareTwoFileTimesAndCopy "${CONF_REAL_DIR}/clients.json" "${CONF_BAK_DIR}/clients.json" "备份"
    compareTwoFileTimesAndCopy "${CONF_REAL_DIR}/hosts.json"   "${CONF_BAK_DIR}/hosts.json"   "备份"
    compareTwoFileTimesAndCopy "${CONF_REAL_DIR}/tasks.json"   "${CONF_BAK_DIR}/tasks.json"   "备份"
	else
    echo_date "备份配置文件 nps.conf clients.json hosts.json tasks.json"
		cp -rf "${CONF_REAL_DIR}/nps.conf"     "${CONF_BAK_DIR}/nps.conf"
    cp -rf "${CONF_REAL_DIR}/clients.json" "${CONF_BAK_DIR}/clients.json"
    cp -rf "${CONF_REAL_DIR}/hosts.json"   "${CONF_BAK_DIR}/hosts.json"
    cp -rf "${CONF_REAL_DIR}/tasks.json"   "${CONF_BAK_DIR}/tasks.json"
	fi
}
# wt增强3.web提交时 更新ssl
on_web_submit_updatessl() {
  # echo_date "web提交时 更新ssl"
  echo_date "web提交时 更新ssl" | tee -a $LOG_FILE
  nps_common_https_default_key_file="$(dbus get nps_common_https_default_key_file)"
  nps_common_https_default_cert_file="$(dbus get nps_common_https_default_cert_file)"
  nps_common_web_key_file="$(dbus get nps_common_web_key_file)"
  nps_common_web_cert_file="$(dbus get nps_common_web_cert_file)"
  # [[ $str == h*]] # ==比较
  # [[ "$str" =~ ^he.* ]] # =~正则比较
  # [[ "$str" =~ ^"${JAR_NAME}".* ]] # 包含变量时，变量使用双引号括起来
  if [[ "${nps_common_https_default_key_file:0:1}" != "/" ]]; then
    echo_date "转换密钥文本为文件:[https_default_key_file.key]" | tee -a $LOG_FILE
    echo -e "${nps_common_https_default_key_file}">${CONF_BAK_DIR}/https_default_key_file.key
    nps_common_https_default_key_file="/koolshare/configs/nps/https_default_key_file.key"
    dbus set nps_common_https_default_key_file="/koolshare/configs/nps/https_default_key_file.key"
	fi
  if [[ "${nps_common_https_default_cert_file:0:1}" != "/" ]]; then
    echo_date "转换证书文本为文件:[https_default_cert_file.pem]" | tee -a $LOG_FILE
    echo -e "${nps_common_https_default_cert_file}">${CONF_BAK_DIR}/https_default_cert_file.pem
    nps_common_https_default_cert_file="/koolshare/configs/nps/https_default_cert_file.pem"
    dbus set nps_common_https_default_cert_file="/koolshare/configs/nps/https_default_cert_file.pem"
	fi
  if [[ "${nps_common_web_key_file:0:1}" != "/" ]]; then
    echo_date "转换密钥文本为文件:[web_key_file.key]" | tee -a $LOG_FILE
    echo -e "${nps_common_web_key_file}">${CONF_BAK_DIR}/web_key_file.key
    nps_common_web_key_file="/koolshare/configs/nps/web_key_file.key"
    dbus set nps_common_web_key_file="/koolshare/configs/nps/web_key_file.key"
	fi
  if [[ "${nps_common_web_cert_file:0:1}" != "/" ]]; then
    echo_date "转换证书文本为文件:[web_cert_file.pem]" | tee -a $LOG_FILE
    echo -e "${nps_common_web_cert_file}">${CONF_BAK_DIR}/web_cert_file.pem
    nps_common_web_cert_file="/koolshare/configs/nps/web_cert_file.pem"
    dbus set nps_common_web_cert_file="/koolshare/configs/nps/web_cert_file.pem"
	fi
}
# wt增强3 比较两个文件时间并复制 
compareTwoFileTimesAndCopy() {
  fileTimes1=$(date +%s -r ${1})
  fileTimes2=$(date +%s -r ${2})
  if [[ "${fileTimes1}" \> "${fileTimes2}" ]];then
    # echo_date "比较时间${3}配置文件 拷贝[${1}]到[${2}] 时间(${fileTimes1})大于时间(${fileTimes2})"
    echo_date "比较时间${3}配置文件 拷贝[${1}]到[${2}] 时间(${fileTimes1})大于时间(${fileTimes2})" | tee -a $LOG_FILE
    cp -rf "${1}" "${2}"
  fi
  # else
  #   echo "文件1[${1}]的时间(${fileTimes1}) 小于 文件2[${2}的时间(${fileTimes2})"
  # fi
}

# 功能
case $1 in
# 1.启动插件
start)
	set_lock
	if [ "${nps_enable}" == "1" ]; then
		logger "[软件中心]: 启动nps！"
		onstart
	fi
	unset_lock
	;;
# 2.重启插件
restart)
	set_lock
	if [ "${nps_enable}" == "1" ]; then
		stop
		onstart
	fi
	unset_lock
	;;
# 3.停止插件
stop)
	set_lock
	stop
	unset_lock
	;;
# 启动 nat?
start_nat)
	set_lock
	if [ "${nps_enable}" == "1" ]; then
		onstart
	fi
	unset_lock
	;;
 backconf)
  set_lock
	if [ "${nps_enable}" == "1" ]; then
		# wt增强2.备份配置文件 参数1(是否比较时间拷贝文件 1:比较时间 0:不比较)
    on_back_conf 1
	fi
	unset_lock
	;;
esac

# 查看日志
case $2 in
web_submit)
	set_lock
  # 清空日志
  true > $LOG_FILE
  # web提交时 更新ssl
  echo "111.web提交时 更新ssl" >> $LOG_FILE
  on_web_submit_updatessl
	http_response "$1"
	if [ "${nps_enable}" == "1" ]; then
		stop | tee -a $LOG_FILE
		onstart | tee -a $LOG_FILE
	else
		stop | tee -a $LOG_FILE
	fi
	echo XU6J03M6 | tee -a $LOG_FILE
	unset_lock
	;;
esac
