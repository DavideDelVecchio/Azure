#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# 
# See the License for the specific language governing permissions and
# limitations under the License.


ADDNS=$1
PDC=$2
BDC=$3
PDCIP=$4
BDCIP=$5
ADMINUSER=$6
DOMAINADMINUSER=$7
DOMAINADMINPWD=$8
ADOUPATH=$9

findOsVersion() {
    # if it's there, use lsb_release
    rpm -q redhat-lsb
    if [ $? -eq 0 ]; then
        os=$(lsb_release -si)
        major_release=$(lsb_release -sr | cut -d '.' -f 1)

    # if lsb_release isn't installed, use /etc/redhat-release
    else
        grep  "CentOS.* 6\." /etc/redhat-release
        if [ $? -eq 0 ]; then
            os="CentOS"
            major_release="6"
        fi
	    grep  "CentOS.* 7\." /etc/redhat-release
        if [ $? -eq 0 ]; then
            os="CentOS"
            major_release="7"
        fi
    fi

    echo "OS: $os $major_release"

    # select the OS and run the appropriate setup script
    not_supported_msg="OS $os $release is not supported."
    if [ "$os" != "CentOS" ]; then
        echo "$not_supported_msg"
        exit 1
	fi
    if [ "$major_release" != "6" ] && [ "$major_release" != "7" ]; then
        echo "$not_supported_msg"
        exit 1
    fi
}

replace_ad_params() {
    target=${1}
    shortdomain=`echo ${ADDNS} | sed 's/\..*$//'`
    sed -i "s/REPLACEADDOMAIN/${ADDNS}/g" ${target}
    sed -i "s/REPLACEUPADDOMAIN/${ADDNS^^}/g" ${target}
    sed -i "s/REPLACESHORTADDOMAIN/${shortdomain}/g" ${target}
    sed -i "s/REPLACEPDC/${PDC}/g" ${target}
    sed -i "s/REPLACEBDC/${BDC}/g" ${target}
    sed -i "s/REPLACEIPPDC/${PDCIP}/g" ${target}
    sed -i "s/REPLACEIPBDC/${BDCIP}/g" ${target}
}

# Disable the need for a tty when running sudo and allow passwordless sudo for the admin user
sed -i '/Defaults[[:space:]]\+!*requiretty/s/^/#/' /etc/sudoers
echo "$ADMINUSER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Disable SELinux
setenforce 0 
sed -i 's^SELINUX=enforcing^SELINUX=disabled^g' /etc/selinux/config

# Install and configure domain join packages
yum -y install realmd
yum -y install sssd
yum -y install sssd-client
yum -y install krb5-workstation krb5-libs
yum -y install policycoreutils-python

os=""
release=""
findOsVersion



# Join domain, must join domain first, otherwise sssd won't start
shortHostName=`hostname -s`
hostname ${shortHostName}.${ADDNS}
n=0
UPPERDOMAIN=$(echo ${ADDNS} | tr 'a-z' 'A-Z' )
echo "value for Upper Domain :" ${UPPERDOMAIN}
echo  ${DOMAINADMINPWD} | kinit ${DOMAINADMINUSER}@${UPPERDOMAIN}
until [ $n -ge 4 ]
do
  if [ ! -z "$ADOUPATH" ]; then
    realm join ${UPPERDOMAIN} --computer-ou=${ADOUPATH} -U ${DOMAINADMINUSER}@${UPPERDOMAIN} --verbose 
  else
    realm join ${ADDNS} -U ${DOMAINADMINUSER}@${UPPERDOMAIN} --verbose
  fi
  result=$?
  [ $result -eq 0 ] && break
  n=$[$n+1]
  sleep 20
done
if [ $result -eq 0 ]; then
  klist -k
  authconfig --enablesssd --enablemkhomedir --enablesssdauth --update
  service sssd restart
  chkconfig sssd on
  hostname ${shortHostName}
  exit 0
else
  hostname ${shortHostName}
  exit 1
fi

