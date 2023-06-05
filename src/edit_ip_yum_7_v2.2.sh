#!/bin/bash
#2023-6-5
#version:1.0
#author:lc
#可以使用DHCP获取地址，也可以配置静态IP
#YUM可以使用镜像、本地其他路径YUM源
#也可以直接下载华为或阿里的YUM源
#为优化使用，因为华为和阿里的YUM源文件需要下载，所以脚本改成了先配置IP，然后配置YUM源

PA=/etc/sysconfig/network-scripts/ifcfg-
n=ens-bak
#获取系统内所有网卡名
E=$(ls /sys/class/net/ | grep "^e")
ETHERS=(${E// /})
#查找一个网卡配置文件
for e in ${ETHERS[@]}
do
 [ -e $PA$e ] && ETHER=$e
 break
done
#备份一个网卡配置文件，给其他网卡当模板
if [ ! -e $PA$n ]
then
 cp -p $PA$ETHER $PA$n
 sed -i "/UUID/d" $PA$n
 sed -i "/ONBOOT/s/no/yes/" $PA$n
 sed -i "/BOOTPROTO/s/dhcp/none/" $PA$n
 rm -f  $PA$ETHER
fi
#通用配置
function e_input(){
t=$1
read -p "请输入网卡$t的IP：" IP
if [ -z $IP ]
then
 sed -i "/BOOTPROTO/s/none/dhcp/" $PA$t
 return
fi
IP1=$(echo $IP | awk -F '.' '{print $1}')
read -p "请输入网卡$t的MASK：" MASK
if [ -z $MASK ]
then
  if [ $IP1 -le 126 ]
  then
    MASK=255.0.0.0
  elif [ $IP1 -le 191 ]
  then
    MASK=255.255.0.0
  elif [ $IP1 -le 223 ]
  then
    MASK=255.255.255.0
  else
    echo "请输入合法IP！"
    e_input $t
    return
  fi
fi
echo "IPADDR=$IP" >> $PA$t
echo "NETMASK=$MASK" >> $PA$t
ether=(${t/:/ /})
if [ ${#ether[@]} -eq 1 ]
then
  read -p "请输入网卡$t的GATEWAY：" GATEWAY
  if [ ! -z $GATEWAY ]
  then
   echo "GATEWAY=$GATEWAY" >> $PA$t
  fi
  read -p "请输入网卡$t的首选DNS：" DNS1
  if [ ! -z $DNS1 ]
  then
   echo "DNS1=$DNS1" >> $PA$t
   read -p "请输入网卡$t的备用DNS：" DNS2
   if [ ! -z $DNS2 ]
   then
    echo "DNS2=$DNS2" >> $PA$t
   fi
  fi
fi
}
for ETH in ${ETHERS[@]}
do
 if [ ! -e $PA$ETH ]
 then
  cp -p $PA$n $PA$ETH
  sed -i "/$ETHER/s/$ETHER/$ETH/g" $PA$ETH
  e_input $ETH
 else
  read -p "是否要修改$ETH的配置：" ANS
  if [ ! -z $ANS ] 
  then
    if  [ $ANS = "y" ] || [ $ANS = "Y" ]
    then
     rm -f $PA$ETH
     cp -p $PA$n $PA$ETH
     sed -i "/$ETHER/s/$ETHER/$ETH/g" $PA$ETH
     e_input $ETH
    fi
  fi
 fi
done
while [ 0 ]
do
 read -p "请输入子接口名字：" ETH
 if [ -z $ETH ]
 then
  break
 else
  rm -f $PA$ETH
  cp -p $PA$n $PA$ETH
  sed -i "/$ETHER/s/$ETHER/$ETH/g" $PA$ETH
  e_input $ETH 
 fi 
done

systemctl stop firewalld
setenforce 0
systemctl restart network

echo "*********************************配置YUM源*************************"
yum clean all &> /dev/null
#yum repolist all  &> /dev/null
rm -f /var/run/yum.pid
echo "1:镜像YUM源"
echo "2:系统中其他YUM源"
echo "3:网络YUM源"
echo "4:huawei"
echo "5:ali"
read -p "请指定YUM源：" YUM_PATH
mv -f /etc/yum.repos.d/*  /tmp
y_pa=/media/cdrom
[ ! -e $y_pa ] && mkdir $y_pa
umount /dev/sr0
mount /dev/sr0 $y_pa
function ca(){
PAT=$1
cat << EOF >> /etc/yum.repos.d/yum.repo
[yum]   
name=media yum
baseurl=file://$PAT
enable=1
gpgcheck=0
EOF
}
case $YUM_PATH in 
2)
 read -p "请输入RPM软件包所在路径：" PAT
 createrepo -g $y_pa/repodata/repomd.xml  $PAT
 ca $PAT
 ;;
3)
 echo "例如:https://repo.huaweicloud.com/centos/\$releasever/os/\$basearch/"
 read -p "请输入网络YUM源地址：" PAT
cat << EOF >> /etc/yum.repos.d/yum.repo
[yum]   
name=network yum
baseurl=$PAT
enable=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
;;
4)
 wget -O /etc/yum.repos.d/CentOS-Base.repo https://repo.huaweicloud.com/repository/conf/CentOS-7-reg.repo
 ;;
5)
 wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
 ;;
*)
 ca $y_pa
esac
yum -y install gcc* > /dev/null

