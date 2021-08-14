#!/bin/sh
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
MODEL=
UI_TYPE=ASUSWRT
FW_TYPE_CODE=
FW_TYPE_NAME=
DIR=$(cd $(dirname $0); pwd)
module=${DIR##*/}

# 0.实现暂停功能 方便调试
function pause() {
  read -n 1 -p "$*" inp
  if [ "${inp}" != "" ] ; then
    echo -e "${inp}"
  fi
}

# 1.获取路由器机型名称: 如:RT-AX86U
get_model(){
  local ODMPID=$(nvram get odmpid)
  local PRODUCTID=$(nvram get productid)
  if [ -n "${ODMPID}" ];then
    MODEL="${ODMPID}"
  else
    MODEL="${PRODUCTID}"
  fi
}

# 2.获取固件类型 如: FW_TYPE_CODE="1" FW_TYPE_NAME="华硕官方固件"
get_fw_type() {
  local KS_TAG=$(nvram get extendno|grep koolshare)
  if [ -d "/koolshare" ];then
    if [ -n "${KS_TAG}" ];then
      FW_TYPE_CODE="2"
      FW_TYPE_NAME="koolshare官改固件"
    else
      FW_TYPE_CODE="4"
      FW_TYPE_NAME="koolshare梅林改版固件"
    fi
  else
    if [ "$(uname -o|grep Merlin)" ];then
      FW_TYPE_CODE="3"
      FW_TYPE_NAME="梅林原版固件"
    else
      FW_TYPE_CODE="1"
      FW_TYPE_NAME="华硕官方固件"
    fi
  fi
}

# 3.平台测试(是否符合安装需求) => 符合:继续安装 不符合:退出安装
platform_test(){
  local LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
  if [ -d "/koolshare" -a -f "/usr/bin/skipd" -a "${LINUX_VER}" -ge "41" ];then
    echo_date 机型："${MODEL} ${FW_TYPE_NAME} 符合安装要求，开始安装插件！"
  else
    exit_install 1
  fi
}

# 获取ui类型
get_ui_type(){
  # default value
  [ "${MODEL}" == "RT-AC86U" ] && local ROG_RTAC86U=0
  [ "${MODEL}" == "GT-AC2900" ] && local ROG_GTAC2900=1
  [ "${MODEL}" == "GT-AC5300" ] && local ROG_GTAC5300=1
  [ "${MODEL}" == "GT-AX11000" ] && local ROG_GTAX11000=1
  [ "${MODEL}" == "GT-AXE11000" ] && local ROG_GTAXE11000=1
  local KS_TAG=$(nvram get extendno|grep koolshare)
  local EXT_NU=$(nvram get extendno)
  local EXT_NU=$(echo ${EXT_NU%_*} | grep -Eo "^[0-9]{1,10}$")
  local BUILDNO=$(nvram get buildno)
  [ -z "${EXT_NU}" ] && EXT_NU="0" 
  # RT-AC86U
  if [ -n "${KS_TAG}" -a "${MODEL}" == "RT-AC86U" -a "${EXT_NU}" -lt "81918" -a "${BUILDNO}" != "386" ];then
    # RT-AC86U的官改固件，在384_81918之前的固件都是ROG皮肤，384_81918及其以后的固件（包括386）为ASUSWRT皮肤
    ROG_RTAC86U=1
  fi
  # GT-AC2900
  if [ "${MODEL}" == "GT-AC2900" ] && [ "${FW_TYPE_CODE}" == "3" -o "${FW_TYPE_CODE}" == "4" ];then
    # GT-AC2900从386.1开始已经支持梅林固件，其UI是ASUSWRT
    ROG_GTAC2900=0
  fi
  # GT-AX11000
  if [ "${MODEL}" == "GT-AX11000" -o "${MODEL}" == "GT-AX11000_BO4" ] && [ "${FW_TYPE_CODE}" == "3" -o "${FW_TYPE_CODE}" == "4" ];then
    # GT-AX11000从386.2开始已经支持梅林固件，其UI是ASUSWRT
    ROG_GTAX11000=0
  fi
  # ROG UI
  if [ "${ROG_GTAC5300}" == "1" -o "${ROG_RTAC86U}" == "1" -o "${ROG_GTAC2900}" == "1" -o "${ROG_GTAX11000}" == "1" -o "${ROG_GTAXE11000}" == "1" ];then
    # GT-AC5300、RT-AC86U部分版本、GT-AC2900部分版本、GT-AX11000部分版本、GT-AXE11000全部版本，骚红皮肤
    UI_TYPE="ROG"
  fi
  # TUF UI
  if [ "${MODEL}" == "TUF-AX3000" ];then
    # 官改固件，橙色皮肤
    UI_TYPE="TUF"
  fi
}

# 退出安装 => 不带参数:正常退出 参数:1不支持安装 
exit_install(){
  local state=$1
  case $state in
    1)
      echo_date "本插件适用于【koolshare 梅林改/官改 hnd/axhnd/axhnd.675x】固件平台！"
      echo_date "你的固件平台不能安装！！!"
      echo_date "本插件支持机型/平台：https://github.com/koolshare/rogsoft#rogsoft"
      echo_date "退出安装！"
      rm -rf /tmp/${module}* >/dev/null 2>&1
      exit 1
      ;;
    0|*)
      rm -rf /tmp/${module}* >/dev/null 2>&1
      exit 0
      ;;
  esac
}

# 安装不同的ui 主要替换asp文件中的 值
install_ui(){
    # 
  # intall different UI
  get_ui_type
  if [ "${UI_TYPE}" == "ROG" ];then
    echo_date "安装ROG皮肤！"
    sed -i '/asuscss/d' /koolshare/webs/Module_${module}.asp >/dev/null 2>&1
  fi
  if [ "${UI_TYPE}" == "TUF" ];then
    echo_date "安装TUF皮肤！"
    sed -i '/asuscss/d' /koolshare/webs/Module_${module}.asp >/dev/null 2>&1
    sed -i 's/3e030d/3e2902/g;s/91071f/92650F/g;s/680516/D0982C/g;s/cf0a2c/c58813/g;s/700618/74500b/g;s/530412/92650F/g' /koolshare/webs/Module_${module}.asp >/dev/null 2>&1
  fi
  if [ "${UI_TYPE}" == "ASUSWRT" ];then
    echo_date "安装ASUSWRT皮肤！"
    sed -i '/rogcss/d' /koolshare/webs/Module_${module}.asp >/dev/null 2>&1
  fi
}

# 4.开始安装插件
install_now(){
  # 1.默认值
  # default value
  local TITLE="nps"
  local DESCR="一款轻量级、高性能、功能强大的内网穿透代理服务器。"
  local PLVER=$(cat ${DIR}/version)

  # 2.停止服务
  # stop first
  local ENABLE=$(dbus get ${module}_enable)
  if [ "${ENABLE}" == "1" -a -f "/koolshare/scripts/${module}_config.sh" ];then
    echo_date "安装前先关闭${TITLE}插件，以保证更新成功！"
    sh /koolshare/scripts/${module}_config.sh stop >/dev/null 2>&1
  fi

  # 3.首先移除一些文件
  # remove some file first
  find /koolshare/init.d -name "*nps*" | xargs rm -rf >/dev/null 2>&1

  # 4.安装插件相关文件
  # isntall file
  echo_date "安装插件相关文件..."
  cd /tmp
  cp -rf /tmp/${module}/bin/* /koolshare/bin/
  cp -rf /tmp/${module}/res/* /koolshare/res/
  cp -rf /tmp/${module}/scripts/* /koolshare/scripts/
  cp -rf /tmp/${module}/webs/* /koolshare/webs/
  cp -rf /tmp/${module}/uninstall.sh /koolshare/scripts/uninstall_${module}.sh
  if [ ! -d "/etc/${module}/" ];then
    echo_date "文件[/etc/${module}/]不存在, 开始拷贝[/koolshare/res/${module}/]到[/etc/]"
    # mkdir -p /etc/nps/
	  # cp -rf /koolshare/res/${module}/* /etc/nps/
	  cp -rf /koolshare/res/${module}/ /etc/
  fi
  pause "拷贝资源完成"

  # 5.修改文件全选
  # Permissions
  chmod 755 /koolshare/bin/* >/dev/null 2>&1
  chmod 755 /koolshare/scripts/* >/dev/null 2>&1

  # 6.添加开机自启动连接
  # make start up script link
  if [ ! -L "/koolshare/init.d/S98${module}.sh" -a -f "/koolshare/scripts/${module}_config.sh" ];then
    ln -sf /koolshare/scripts/${module}_config.sh /koolshare/init.d/S98${module}.sh
  fi
  
  # 7.安装不同ui
  # intall different UI
  install_ui

  # 8.设置插件默认参数
  # dbus value
  echo_date "设置插件默认参数..."
  dbus set ${module}_version="${PLVER}"
  dbus set softcenter_module_${module}_version="${PLVER}"
  dbus set softcenter_module_${module}_install="1"
  dbus set softcenter_module_${module}_name="${module}"
  dbus set softcenter_module_${module}_title="${TITLE}"
  dbus set softcenter_module_${module}_description="${DESCR}"

  # 9.设置默认参数
  # defalut value
  local VERSION=$(cat $DIR/version)
  dbus set ${module}_version="${VERSION}"
  dbus set ${module}_client_version=$(/koolshare/bin/${module} --version)

  # 如果配置不存在 那么设置默认值
  if [ "$(dbus get ${module}_common_bridge_port)" == "" ];then
    dbus set ${module}_common_bridge_port="85"
  fi
  if [ "$(dbus get ${module}_common_web_port)" == "" ];then
    dbus set ${module}_common_web_port="86"
  fi
  if [ "$(dbus get ${module}_common_web_username)" == "" ];then
    dbus set ${module}_common_web_username="admin"
  fi
  if [ "$(dbus get ${module}_common_web_password)" == "" ];then
    dbus set ${module}_common_web_password="test123"
  fi
  if [ "$(dbus get ${module}_common_http_proxy_port)" == "" ];then
    dbus set ${module}_common_http_proxy_port="55"
  fi
  if [ "$(dbus get ${module}_common_https_proxy_port)" == "" ];then
    dbus set ${module}_common_https_proxy_port="66"
  fi
  if [ "$(dbus get ${module}_common_allow_ports)" == "" ];then
    dbus set ${module}_common_allow_ports="9001-9009,10001,11000-12000"
  fi
  if [ "$(dbus get ${module}_common_allow_user_login)" == "" ];then
    dbus set ${module}_common_allow_user_login="false"
  fi
  if [ "$(dbus get ${module}_common_allow_user_register)" == "" ];then
    dbus set ${module}_common_allow_user_register="false"
  fi

  if [ "$(dbus get ${module}_common_cron_hour_min)" == "" ];then
    dbus set ${module}_common_cron_hour_min="hour"
  fi
  if [ "$(dbus get ${module}_common_cron_time)" == "" ];then
    dbus set ${module}_common_cron_time="0"
  fi
  if [ "$(dbus get ${module}_common_cron2_hour_min)" == "" ];then
    dbus set ${module}_common_cron2_hour_min="min"
  fi
  if [ "$(dbus get ${module}_common_cron2_time)" == "" ];then
    dbus set ${module}_common_cron2_time="5"
  fi
  

  # 10.安装完毕 重启插件
  # re-enable
  if [ "${ENABLE}" == "1" -a -f "/koolshare/scripts/${module}_config.sh" ];then
    echo_date "安装完毕，重新启用${TITLE}插件！"
    sh /koolshare/scripts/nps_config.sh restart
  fi
  
  # 11.完成插件安装
  # finish
  echo_date "${TITLE}插件安装完毕！"
  exit_install
}

install(){
  # if [ ! -d "/tmp/${module}/" ];then
  #   echo_date "文件夹[/tmp/${module}/]不存在, 即将开始拷贝[/tmp/home/root/${module}/]到[/tmp/]"
  #   # mkdir -p /tmp/nps/
  #   # cp -rf /tmp/home/root/${module}/* /tmp/nps/
  # 	cp -rf /tmp/home/root/${module}/ /tmp/
  # fi
  # 1.获取路由器机型名称: 如:RT-AX86U
  get_model
  # 2.获取固件类型 如: FW_TYPE_CODE="1" FW_TYPE_NAME="华硕官方固件"
  get_fw_type
  
  # 3.平台测试(是否符合安装需求) => 符合:继续安装 不符合:退出安装
  platform_test
  
  # 4.开始安装插件
  install_now
}

install
