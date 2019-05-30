#!/bin/bash

usage() { 
	echo "Usage:" 
	echo "-S: Indicates wether you want to share a hiera or not"
	echo "-p: Puppet environment to be used"
	echo "-i: IP assigned to this puppet master, added in the /etc/hosts"
	echo "-m: Name of the module to be mounted"
	echo "-M: Puppet environment in where this module will be mounted"
}
ENVIRONMENT=""
SHAREDHIERA=false
MODULE_NAME=""
MODULE_PUPPET_ENV=""
IP=""
while getopts ":Sp:m:M:i:" o; do
	case "${o}" in
			S)
					SHAREDHIERA=true
					;;
			p)
					ENVIRONMENT=${OPTARG}
					;;
			m)
					MODULE_NAME=${OPTARG}
					;;
			M)
					MODULE_PUPPET_ENV=${OPTARG}
					;;
			i)
			    IP=${OPTARG}
					;;
			*)
					usage
					;;
	esac
done
shift $((OPTIND-1))

echo "Options received:"
echo -e "\t * Puppet IP: $IP"
echo -e "\t * Shared Hiera: $SHAREDHIERA"
echo -e "\t * Puppet Environment: $ENVIRONMENT"
echo -e "\t * Module Name: $MODULE_NAME"
echo -e "\t * Module Puppet Environment: $MODULE_PUPPET_ENV"

rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm
yum install -y puppetserver git
sed -i 's#\-Xms2g#\-Xms512m#g;s#\-Xmx2g#\-Xmx512m#g' /etc/sysconfig/puppetserver
echo -e "certname = puppet-master.dev.lsst.org" >> /etc/puppetlabs/puppet/puppet.conf
echo -e "\n[main]\nenvironment = production" >> /etc/puppetlabs/puppet/puppet.conf
echo -e "\n[agent]\nserver = puppet-master.dev.lsst.org" >> /etc/puppetlabs/puppet/puppet.conf
echo -e "${IP}\tpuppet-master\tpuppet-master.dev.lsst.org" > /etc/hosts

sed -i 's#^PATH=.*#PATH=$PATH:/opt/puppetlabs/puppet/bin:$HOME/bin#g' /root/.bash_profile

#TODO HoxFix -> This installation should be removed once bug <https://github.com/puppetlabs/r10k/issues/930> is fixed
/opt/puppetlabs/puppet/bin/gem install cri:2.15.6
/opt/puppetlabs/puppet/bin/gem install r10k

if [ ! -d /etc/puppetlabs/r10k/ ]
then
	mkdir -p /etc/puppetlabs/r10k/
fi

if [ ! -d /etc/puppetlabs/code/hieradata/ ]
then
	mkdir -p /etc/puppetlabs/code/hieradata/production
fi

if  $SHAREDHIERA ;
then 
	if [ -z "$(grep etc_puppetlabs_code_hieradata_production /etc/fstab)" ]
	then
	echo "etc_puppetlabs_code_hieradata_production /etc/puppetlabs/code/hieradata/production vboxsf defaults,ro 0 0" >> /etc/fstab
		mount -a
	fi
	echo -e "---
:cachedir: '/var/cache/r10k'

# Hiera repo not configured thru r10k since is leveraging a shared folder
:sources:
  :lsst.org:
    remote: 'https://github.com/lsst/itconf_l1ts.git'
    basedir: '/etc/puppetlabs/code/environments'
" > /etc/puppetlabs/r10k/r10k.yaml
else
	echo -e "---
:cachedir: '/var/cache/r10k'

# Hiera repo not configured thru r10k since is leveraging a shared folder
:sources:
  :lsst.org:
    remote: 'https://github.com/lsst/itconf_l1ts.git'
    basedir: '/etc/puppetlabs/code/environments'

  :hieradata:
    remote: https://github.com/LSST-IT/lsst-sandbox-hiera.git
    basedir: '/etc/puppetlabs/code/hieradata'
" > /etc/puppetlabs/r10k/r10k.yaml
fi
/opt/puppetlabs/puppet/bin/r10k deploy environment -t


if $SHAREDHIERA ;
then
	for f in $(ls -1 /etc/puppetlabs/code/environments/)
	do
		echo "Found environment $f"
		if [ ! -d "/etc/puppetlabs/code/hieradata/$f" ]
		then
			echo "dir $f don't exists, creating it from production"
			ln -s /etc/puppetlabs/code/hieradata/production /etc/puppetlabs/code/hieradata/$f
		fi
	done
fi

if [ ! -d /opt/puppet-code ]
then
	mkdir /opt/puppet-code
fi

# If there is a shared folder for the puppet code
if [ ! -z "$(VBoxControl sharedfolder list | grep opt_puppet-code)" ]
then
	# if the sharefolder is not in the fstab yet
	if [ -z "$(grep opt_puppet-code /etc/fstab)" ]
	then
		echo "Shared puppet code dir found, mounted into: /etc/puppetlabs/code/environments/$ENVIRONMENT"
		echo "opt_puppet-code /opt/puppet-code vboxfs defaults,ro 0 0" >> /etc/fstab
		echo "/opt/puppet-code /etc/puppetlabs/code/environments/$ENVIRONMENT none defaults,ro,bind 0 0" >> /etc/fstab
		mount -a
	fi
fi

if [ ! -f /etc/puppetlabs/puppet/autosign.conf ]
then
	echo "*.vm.dev.lsst.org" > /etc/puppetlabs/puppet/autosign.conf
fi

systemctl enable puppetserver
systemctl start puppetserver

# Registering against the puppet server and sending certificate
/opt/puppetlabs/puppet/bin/puppet agent -t

systemctl restart puppetserver

# This mount is being done at the very end to avoid conflicts with r10k and puppet agent.

# If there is a shared folder for the puppet code
if [ ! -z "$(VBoxControl sharedfolder list | grep opt_${MODULE_NAME})" ] 
then
	# if the sharefolder is not in the fstab yet
	if [ -z "$(grep opt_${MODULE_NAME} /etc/fstab)" ]
	then
		echo "Shared puppet module code dir found, mounted into: /etc/puppetlabs/code/environments/${MODULE_PUPPET_ENV}/modules/${MODULE_NAME}"
		echo "opt_${MODULE_NAME} /opt/${MODULE_NAME} vboxfs defaults,ro 0 0" >> /etc/fstab
		echo "/opt/${MODULE_NAME} /etc/puppetlabs/code/environments/${MODULE_PUPPET_ENV}/modules/${MODULE_NAME} none defaults,ro,bind 0 0" >> /etc/fstab
		mount -a
	fi
fi