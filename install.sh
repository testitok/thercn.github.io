#!/bin/bash

strUsername=
strToken=
strAddress="download.51miaole.com"
scriptAddress="https://flynat.api.51miaole.com/api/v1/download/script/"
strVersion="0.31.2"
installDir="/usr/local/flynat"

if [[ $UID -ne 0 ]]; then
	echo "运行此脚本需要超级用户权限。"
	exit 1
fi

usage()
{
	cat << EOT

Usage :  ${0} [OPTION] ...
  install client

Options:
  --token 		token string
  --username 	username string
EOT
}


while [[ true ]]; do
	case "$1" in
		--token )
			strToken=$2
			shift 2
			;;
		--username )
			strUsername=$2
			shift 2
			;;
		--help )
			usage
			exit 0
			;;
		* )
			usage
			exit 1
			;;
	esac
	if [[ $# == 0 ]]; then
		break
	fi
done

if [[ "$strUsername" == "" ]]; then
		echo username cannot be empty
	exit 1
fi

if [[ "$strToken" == "" ]]; then
	echo token cannot be empty
	exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]
then
    red=''
    green=''
    yellow=''
    magenta=''
    cyan=''
    none=''
else
    red='\e[91m'
    green='\e[92m'
    yellow='\e[93m'
    magenta='\e[95m'
    cyan='\e[96m'
    none='\e[0m'
fi

## ----------------------------------------
## 第一阶段     确认运行
## ----------------------------------------

## 起始提示
echo -e "提示:"
echo -e "  1. 如需退出脚本, 请按下 ${magenta}Ctrl-C${none} 组合键退出."
echo -e "  2. 在 Linux Shell 中, 复制并不是使用 ${magenta}Ctrl-C${none} 组合键, 请自行寻找你所使用的的终端程序的复制按钮."
echo -e "  3. 如果你的系统没有安装 curl , 请先安装 curl ."
echo -e "      Ubuntu/Debian 安装 curl 命令: ${magenta}apt-get install -y curl${none}"
echo -e "      CentOS 安装 curl 命令:        ${magenta}yum install -y curl${none}"
echo -e "  4. 安装前请检查网络连接以及系统权限."
echo -e "  5. 配置映射可在 ${yellow}https://flynat.51miaole.com/oms/proxy${none} 处添加编辑."
echo -e "  6. 本脚本已经适配 macOS 系统."
echo -e ""

read -p "$(echo -e "继续运行请按 ${yellow}Enter${none} 键, 退出请按 ${magenta}Ctrl-C${none} 键.")" go


## ----------------------------------------
## 第二阶段     检测
## ----------------------------------------

echo "正在检测运行环境..."

sysType=$(uname -s)
if [[ "$sysType" == "Darwin" ]]; then
	sysType="darwin_amd64"
elif [[ "$sysType" == "Linux" ]]; then
		sysType="linux_amd64"
		archType=$(uname -m)
		if [[ $archType == aarch64 ]] ;
		then
		    sysType="linux_arm64"
		elif  [[ $archType == arm* ]] ;
		then
			sysType="linux_arm"
		elif  [[ $archType == i*86 ]] ;
		then
			sysType="linux_386"
		# support openwrt mips
		elif  [[ $archType == mips ]] ;
		then
			sysType="linux_mipsle"
			ls /lib |grep mipsel
			if [[ $? -ne 0 ]]; then
				# mipsel not found, it's mipseb
				sysType="linux_mipsbe"
			fi
		fi
fi

## 输出提示
echo -e "|- 当前系统类型_硬件架构是: ${yellow}${sysType}${none}"
               # 注: 本命令对应的指令在某些系统上不可用
echo -e "|- 当前系统时间是: ${yellow}$(date +"%Y 年 %m 月 %d 日   %H 时 %M 分")${none}"


systemName=$(uname -s)

if [[ $systemName == 'Linux' ]];then
  if [[ $(command -v systemctl) ]]; then
    manager='systemctl'
  elif [[ $(command -v service) ]]; then
    manager='service'
  else
    manager='rc_local'
  fi
elif [[ $systemName == 'Darwin' ]]; then
    manager='darwin'
fi


Get_GNU_Name()
{
    if grep -Eqi "CentOS" /etc/issue >/dev/null 2>&1 || grep -Eq "CentOS" /etc/*-release >/dev/null 2>&1; then
        DISTRO='Centos'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue >/dev/null 2>&1 || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release >/dev/null 2>&1; then
        DISTRO='RHEL'
    elif grep -Eqi "Aliyun" /etc/issue >/dev/null 2>&1 || grep -Eq "Aliyun" /etc/*-release >/dev/null 2>&1; then
        DISTRO='Aliyun'
    elif grep -Eqi "Fedora" /etc/issue >/dev/null 2>&1 || grep -Eq "Fedora" /etc/*-release >/dev/null 2>&1; then
        DISTRO='Fedora'
    elif grep -Eqi "Debian" /etc/issue >/dev/null 2>&1 || grep -Eq "Debian" /etc/*-release >/dev/null 2>&1; then
        DISTRO='Debian'
    elif grep -Eqi "Ubuntu" /etc/issue >/dev/null 2>&1 || grep -Eq "Ubuntu" /etc/*-release >/dev/null 2>&1; then
        DISTRO='Ubuntu'
    elif grep -Eqi "Raspbian" /etc/issue >/dev/null 2>&1 || grep -Eq "Raspbian" /etc/*-release >/dev/null 2>&1; then
        DISTRO='Raspbian'
    else
        if uname -a |grep -Eq "synology"; then
            DISTRO='Synology'
        elif uname -a |grep -Eq "Darwin"; then
            DISTRO='Darwin'
        elif uname -a |grep -Eq "OpenWrt"; then
            DISTRO='Openwrt'
        else
          DISTRO='unknow'
        fi
    fi
    echo $DISTRO;
}


check_res() {
  res=$1
  if [[ $res -ne 0 ]];then
    echo -e "      ${red}失败!${none}"
  else
    echo -e "      ${green}成功!${none}"
  fi
}


install() {
  distro=$(Get_GNU_Name)
  clientName="flynat_${strVersion}_${sysType}"
  ClientPackageName="${clientName}.tar.gz"
  binURL="https://$strAddress/shell/${ClientPackageName}"
  # 下载客户端
  echo -e "|- 下载客户端...\c"
  curl -so ${ClientPackageName} $binURL >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
      # curl not found, try wget download
      wget -qO ${ClientPackageName} $binURL >/dev/null
  fi
  check_res $?
  # 下载管理客户端脚本
  echo -e "|- 下载管理客户端脚本...\c"
  postData="username=$strUsername&token=$strToken&install_dir=$installDir&manager=$manager&distro=$distro"
  curl -so flynatc_manage.sh -d $postData $scriptAddress >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      # curl not found, try wget download
      wget -qO flynatc_manage.sh --post-data=$postData $scriptAddress >/dev/null
  fi
  check_res $?
  # 安装客户端
  echo -e "|- 安装客户端...\c"
  chmod +x flynatc_manage.sh
  chmod +x ${ClientPackageName}
  tar xzf ${ClientPackageName} && rm -rf ${ClientPackageName}
  mkdir -p ${installDir}/logs
  mv ${clientName}/flynatc $installDir && rm -rf ${clientName}
  chmod u+x $installDir/flynatc && cp flynatc_manage.sh $installDir/manage.sh
  check_res $?
  # 设置开机自启动
  read -p "$(echo -e "是否安装为系统服务并设置开机自启动?(y/N) : ")" FLYNAT_SERVICE
  if [[ "${FLYNAT_SERVICE}" == "y" || "${FLYNAT_SERVICE}" == "Y" ]]
  then
        echo -e "|- 设置开机自启动...\c"
        /bin/bash $installDir/manage.sh enable
        check_res $?
  fi
  echo -e "|- 启动客户端服务...\c"
  start
  echo -e "客户端安装路径: ${magenta}$installDir${none}"
  echo -e "客户端管理脚本: ${magenta}$installDir/manage.sh${none}"
  echo -e "使用 ${magenta}$installDir/manage.sh start${none} 命令启动映射服务"
  echo -e "使用 ${magenta}$installDir/manage.sh stop${none} 命令关闭服务"
  echo -e "使用 ${magenta}$installDir/manage.sh status && $installDir/manage.sh logs${none} 命令查看服务状态和 flynatc 日志"
  echo -e "使用 ${magenta}$installDir/manage.sh uninstall${none} 命令${red}卸载${none}客户端"
  echo -e "客户端安装成功, 配置隧道请进入后台添加映射 ${yellow}https://flynat.51miaole.com/oms/proxy${none}"
}

start() {
  /bin/bash $installDir/manage.sh start
}


## ----------------------------------------
## 第三阶段     下载 & 权限处理
## ----------------------------------------
install