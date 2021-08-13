# merlin_nps
nps server for merlin

# 说明
本插件参考了[frps插件](https://github.com/koolshare/rogsoft)，根据[nps插件](https://github.com/ehang-io/nps)打好的包进行二次封装，
本机基于AX86U进行测试，适用于koolshare 梅林改/官改 hnd/axhnd/axhnd.675x固件平台，其他机型未测试
目前已经bug: nps默认的配置文件目录[/etc/nps/]，在路由器重启后会丢失，待解决

# 更新日志：
Koolshare Nps Changelog
===========================================
v0.26.10.1
	- 第一个beta版本
v0.26.10.2
  - 添加端口防火墙设置
v0.26.10.3
  - 添加自定义端口范围以及自定端口的自动添加防火墙放行、允许多用户登录、允许用户注册的配置
