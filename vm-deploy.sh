#!/bin/bash

# Generate standard adits Debian VM

SSHKEY="/root/vm-deploy/authorized_keys"
MASTER="debian10-master"
IMAGEPATH="/var/lib/libvirt/images"
NAME=$(pwgen -n1 -A 4)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
EXTARG=""

usage() {
	echo "Usage: $0 [-h] [-s SIZE_TO_BE_ADDED] [-i] [-n NAME]"
	echo "Creates a basic Debian 10 VM." 
	echo "-i uses custom /etc/network/interfaces"
	echo "-s New size, has to be >20G"
	echo "Defaults are 20G, DHCP, random"
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

set_ip() {
	EXTARG="--copy-in $DIR/interfaces:/etc/network/"
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
			set_ip
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


virt-sysprep -d $MASTER $EXTARG \
--firstboot-command "dpkg-reconfigure openssh-server" \
--ssh-inject root:file:$SSHKEY \
--hostname $NAME \
--firstboot-install "vim,unattended-upgrades" \
--update \
--root-password disabled

virt-clone --original $MASTER --name $NAME --auto-clone

if [[ $VMSIZE ]]; then
	resize
fi

virsh start $NAME
