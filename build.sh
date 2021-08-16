#!/bin/sh

MODULE="nps"
VERSION="v1.1.2"
TITLE="nps"
DESCRIPTION="一款轻量级、高性能、功能强大的内网穿透代理服务器。"
HOME_URL="Module_nps.asp"
TAGS="内网穿透 DDNS"
AUTHOR="clang"

# Check and include base
DIR="$( cd "$( dirname "$BASH_SOURCE[0]" )" && pwd )"

# now include build_base.sh
. $DIR/../softcenter/build_base.sh

# change to module directory
cd $DIR

# do something here
do_build_result
