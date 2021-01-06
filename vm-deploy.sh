#!/bin/bash

# Generate standard adits Debian VM

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SSHKEY="$DIR/authorized_keys"
MASTER="debian10-master"
IMAGEPATH="/var/lib/libvirt/images"
NAME=$(pwgen -n1 -A 4)
EXTARG=""

usage() {
	echo "Usage: $0 [-h] [-s SIZE_TO_BE_ADDED] [-i] [-n NAME]"
	echo "Creates a basic Debian 10 VM." 
	echo "-i uses custom /etc/network/interfaces"
	echo "-s New size, has to be > master image"
	echo "Defaults are size of master image, DHCP, random"
	exit 1
}

resize() {
	echo "Exanding image to $VMSIZE"
	mv $IMAGEPATH/$NAME.qcow2 $IMAGEPATH/$NAME-old.qcow2
	qemu-img create -f qcow2 -o preallocation=metadata $IMAGEPATH/$NAME.qcow2 $VMSIZE
	virt-resize --expand /dev/sda1 $IMAGEPATH/$NAME-old.qcow2 $IMAGEPATH/$NAME.qcow2
	if [[ $? == 0 ]]; then
		rm $IMAGEPATH/$NAME-old.qcow2
	else
		echo "Resizing failed"
		exit
	fi
}

while getopts ":hs:in:" opt; do
        case ${opt} in
		h )
			usage
			;;
		s )
			VMSIZE=$OPTARG
			;;
		i )
			STATICIP=1
			;;
		n)
			NAME=$OPTARG
			;;
		: )
			usage
			;;
	esac
done
shift $((OPTIND -1))


if [[ -f $SSHKEY ]]; then
	EXTARG="{$EXTARG} --ssh-inject $SSHKEY"
fi

if [[ $STATICIP == 1 ]]; then	
	EXTARG="${EXTARG} --copy-in $DIR/interfaces:/etc/network/"
else
	EXTARG="${EXTARG} --copy-in $DIR/defaults/interfaces:/etc/network/"
fi

virt-sysprep -d $MASTER $EXTARG \
--firstboot-command "dpkg-reconfigure openssh-server" \
--hostname $NAME \
--firstboot-install "vim,unattended-upgrades" \
--update \
--operations abrt-data,backup-files,bash-history,blkid-tab,crash-data, \
cron-spool,customize,dhcp-client-state,dhcp-server-state,dovecot-data, \
logfiles,lvm-uuids,machine-id,mail-spool,net-hostname,net-hwaddr,pacct-log, \
package-manager-cache,pam-data,passwd-backups,puppet-data-log,rh-subscription-manager,\
rhn-systemid,rpm-db,samba-db-log,script,smolt-uuid,ssh-hostkeys,ssh-userdir \
sssd-db-log,tmp-files,udev-persistent-net,utmp,user-accout \
--root-password disabled

virt-clone --original $MASTER --name $NAME --auto-clone

if [[ $VMSIZE ]]; then
	resize
fi


virsh start $NAME
