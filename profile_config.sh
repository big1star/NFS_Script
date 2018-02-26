#!/bin/sh
# 
# profile_config.sh
# Author: Walle (chenweiqi@cvte.com)
# Date: 2018/2/7:23:10:42
# Description: Execute this script on board, to config profile for NFS.
# Modify: 

#default profile path
#PROFILE_PATH="/Customer/profile"
PROFILE_PATH="./profile"

#default profile backup name
BACKUP_PROFILE_NAME="profile_backup_walle"

#list of partion need to be mount by NFS
PARTITION_LIST="/mslib /applications"

#default NFS option
NFS_OPTIONS="nfsvers=3,vers=3,proto=tcp,nolock"

USER_OPTIONS="disable enable"

#FLAG
NETWORK_CONFIG_FLAG="network config start."

#network default config
ETHER="eth0"

# Function: Backup raw profile and do nothing if backup file is existed.
# para1: Path of profile
# Return none
BackupProfile()
{
    profile_path=$1
	if [ -f $DO_PROFILE_PATH ]; then
        profile_parent_path=${profile_path%/*}
        backup_profile_name=${profile_parent_path}"/$BACKUP_PROFILE_NAME"
        if [ -f $backup_profile_name ]; then
            echo "Profile backup is existed. Don't need to backup again."
        else
            cp $profile_path $backup_profile_name -f
        fi
	else
		echo "Profile $DO_PROFILE_PATH not exist!"
		exit 1
	fi   
}

# Function: Cover profile file with backup profile.
# para1: Path of profile
# Return none
RecoverProfile()
{    
    profile_path=$1
	if [ -f $DO_PROFILE_PATH ]; then
        profile_parent_path=${profile_path%/*}
        backup_profile_name=${profile_parent_path}"/$BACKUP_PROFILE_NAME"
        if [ -f $backup_profile_name ]; then
            cp $backup_profile_name $profile_path -f
            rm $backup_profile_name
        else
            echo "Profile backup is not existed. FAILED!!!!!!!!!!!!!!!"
            exit 1
        fi
	else
		echo "Profile $DO_PROFILE_PATH not exist!"
		exit 1
	fi   
}


# Function
#
# Return current system IP address.
GetIpAddr()
{
	ip_addr=$(ifconfig $ETHER | grep "inet addr" | awk '{ print $2}' | awk -F: '{print $2}')
	echo $ip_addr
}

# Function
#
# Return current system gateway address.
GetGatewayAddr()
{
	gw_addr=$(route | grep 'default' | awk '{print $2}')
	echo $gw_addr
}

#Function
#
#Return current system mac address
GetMacAddr()
{	
	mac_addr=$(ifconfig $ETHER | grep "HWaddr" | awk '{ print $5}')
	echo $mac_addr
}

# Function: Check the input string, if string not in "xxx.xxx.xxx.xxx" format, exit 1
# para $1: string need check
# Return none
CheckIpFormat()
{
	input_str=$1
	if [ "$(echo $input_str | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}$')" == "" ]; then
		echo 'Address $input_str is invalid! Please check your network!'	
		exit 1
	fi
}

# Function: Check the input string, if string not in "xx.xx.xx.xx.xx.xx" format, exit 1
# para $1: string need check
# Return none
CheckMacFormat()
{
	input_str=$1
	if [ "$(echo $input_str | grep -E '([0-9a-fA-F]{2}\:){5}[0-9a-fA-F]{2}$')" == "" ]; then
		echo 'Mac address $input_str is invalid! Please check your network!'	
		exit 1
	fi
}

# Function: Prepare for the network config
#			Acutual just set a flag.
# para $1: Path of profile
# Return none
PrepareNetworkConfig()
{
    profile_path=$1
    network_config_position=$(sed -n -e "/^#ifconfig $ETHER/=" $profile_path)
    if [ "$network_config_position" == "" ]; then
        echo "Can't start network config correctly!!"
        exit 1
    fi
    sed -i "${network_config_position}i # $NETWORK_CONFIG_FLAG" $profile_path
}

# Function: Change the IP address in profile
# para $1: Path of profile
# para $2: New IP address
# Return none
SetProfileIpAddr()
{
	sed -i "s/#ifconfig $ETHER .*/ifconfig $ETHER $2 netmask 255.255.255.0/g" $1
	echo 'The new ifconfig is: '
	grep "ifconfig" $1
}

# Function: Change the MAC address in profile
# para $1: Path of profile
# para $2: New mac address
# Return none
SetProfileMacAddr()
{
	profile_path=$1
	network_config_start=$(sed -n -e "/$NETWORK_CONFIG_FLAG/=" $profile_path)
	set_new_mac="ifconfig $ETHER hw ether $2"
	sed -i "${network_config_start}a ifconfig $ETHER up" $profile_path
	sed -i "${network_config_start}a $set_new_mac" $profile_path
	sed -i "${network_config_start}a ifconfig $ETHER down" $profile_path
}


# Function: Change the gateway address in profile
# para $1: Path of profile
# para $2: New gateway address
# Return none
SetProfileGatewayAddr()
{
	sed -i "s/#route add default gw .*/route add default gw $2/g" $1
	echo 'The new gateway is: '
	grep "route" $1
}

# Function: Add an '#' char ahead of the default mount operation, 
# 	to remove it's original effect.
# para $1: Path of profile
# para $2: The partition in disk.
# Return none
RemoveOriginalMount()
{
	#echo "Remove Origin"
	profile_path=$1
	partition_path=$2
	mount_str=$(grep "^mount .* $partition_path" $profile_path | sed 's#\/#\\\/#g')
	if [ "$mount_str" != "" ];then
		row_num=$(sed -n -e "/$mount_str/=" $profile_path)
		sed -i "$row_num{s/^/#/}" $profile_path
		sed -i "${row_num}i # original mount" $profile_path
	fi
}


# Function: Remove mounted NFS commmand
# para $1: Path of profile
# Return none
RemoveMountedNFS()
{
	#echo "Remove NFS"
	sed -i "/^mount -t nfs -o $NFS_OPTIONS .*/d" $1
}

# Function: Add new NFS mount command in profile
# para $1: Path of profile
# para $2: The partion in disk
# para $3: NFS path, like 192.168.66.66:/home/user/code/
#	make sure the path was add in /etc/exports in server.
# Return none
AddNFSMount()
{
	#echo "Add NFS"
	profile_path=$1
	partition_path=$2
	old_nfs_command=$(grep "^#mount -t nfs" $profile_path | head -1 | sed 's#\/#\\\/#g')
	nfs_path=${3}${partition_path}
	new_nfs_command="mount -t nfs -o $NFS_OPTIONS $nfs_path $partition_path"
	new_nfs_command=${new_nfs_command//\/\\\/}
	sed -i "/$old_nfs_command/a$new_nfs_command" $profile_path
	echo $new_nfs_command
}

ShowUsage()
{
	echo ""
	echo "Usage 1: ./profile_config.sh @NFS_PATH"
	echo "Usage 2: ./profile_config.sh -o @OPTIONS"
	echo "	enum @OPTIONS {disable, ...}"
	exit 1
}

# Response to user config, enable of disable the NFS.
# para $1: Option value
# Return none
UserConfig()
{	
	config_str=$1
	if [ "$config_str" == "disable" ]; then
        RecoverProfile $PROFILE_PATH
		echo "Recover all success"
	else
		echo "Unknown option $config_str !"
		ShowUsage
	fi
}

# Function: Check if NFS path is valiable.
# para $1: NFS path
# Return: return 1 is check success, or return 0
CheckNFSPath()
{
	if [ "$(echo $1 | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}:.*')" == "" ]; then
		echo 0
	else
		echo 1
	fi
}

# Do the truely config here.
# para $1: Path of profile
# para $2: NFS path, like 192.168.66.66:/home/user/code/
#	make sure the path was add in /etc/exports in server.
# Return none
DoConfig()
{
	DO_PROFILE_PATH=$1
	NFS_ROOT_PATH=$2
	
	check_nfs=$(CheckNFSPath $NFS_ROOT_PATH)
	if [ $check_nfs -ne 1 ];then
		echo "NFS path invalid.Try NFS path like 192.168.66.66:/home/user/code/"
		ShowUsage
	fi

	MAC_ADDR=$(GetMacAddr)
	IP_ADDR=$(GetIpAddr)
	GW_ADDR=$(GetGatewayAddr)

	#check all address, if address is invalid, exit the script.
	CheckMacFormat $MAC_ADDR
	CheckIpFormat $IP_ADDR
	CheckIpFormat $GW_ADDR

	if [ -f $DO_PROFILE_PATH ]; then
		#Set the default IP and gateway during system initial.
		PrepareNetworkConfig $DO_PROFILE_PATH
		SetProfileMacAddr $DO_PROFILE_PATH $MAC_ADDR
		SetProfileIpAddr $DO_PROFILE_PATH $IP_ADDR
		SetProfileGatewayAddr $DO_PROFILE_PATH $GW_ADDR
	
		RemoveMountedNFS $DO_PROFILE_PATH
		#Set the partion mounted by NFS
		for partition in $PARTITION_LIST; do
			RemoveOriginalMount $DO_PROFILE_PATH $partition
			AddNFSMount $DO_PROFILE_PATH $partition $NFS_ROOT_PATH
		done
	else
		echo "Profile $DO_PROFILE_PATH not exist!"
		exit 1
	fi
}

##########
#main here
##########

# check parameters
if [ $# -lt 1 ]; then
{
	ShowUsage
}
fi

# config parameters
if [ $# -eq 1 ]; then
{
    BackupProfile $PROFILE_PATH
	DoConfig $PROFILE_PATH $1
}
else
{
	if [ $1 == "-o" ]; then
		UserConfig $2
	else
		ShowUsage
	fi
}
fi
