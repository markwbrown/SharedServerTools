#!/bin/bash

#First, check we are root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." 2>&1
  exit 1
fi

########################################################################
# Helper functions

replace_config_param(){
	#args: file, key, new_value, (old_value to match against)

	if [ -z "$1" ]
	then
		echo "-Parameter #1 is zero length.-"
		return 1
	fi
        if [ -z "$2" ]
	then
                echo "-Parameter #2 is zero length.-"
                return 1
        fi

        CONFIG_FILE=$1
	TARGET_KEY=$2
	REPLACEMENT_VALUE=$3
	SEARCH_KEY=${4:-".*"}

	if grep -q "^[ ^I]*$TARGET_KEY[ ^I]*" "$CONFIG_FILE"; then
		sed -re 's/^('"$TARGET_KEY"')([[:space:]]+)'"$SEARCH_KEY"'/\1\2'"$REPLACEMENT_VALUE"'/' -i $CONFIG_FILE
	else
	   echo "$TARGET_KEY $REPLACEMENT_VALUE" >> "$CONFIG_FILE"
	fi
	return 0
}

#args: destination_file, config-templates file,
apply_template(){
	rm $1".backup" 2> /dev/null
	cp ${SCRIPT_DIR}/config-templates/$2 $1"~"
	
	#Apply sed filters for all known variables
	sed -i "s/__HOSTNAME_FULL__/${HOSTNAME_FULL}/g" $1"~"
	sed -i "s/__HOSTNAME_SHORT__/${HOSTNAME_SHORT}/g" $1"~"
	sed -i "s/__PRIMARY_IP__/${PRIMARY_IP}/g" $1"~"

	mv $1 $1".backup"
	mv $1"~" $1
	return 0;
}


#############################################################################
# Variables used throughout

SCRIPT_PATH=`realpath $0`
SCRIPT_DIR=`dirname $SCRIPT_PATH`
HOSTNAME_SHORT=`hostname`
HOSTNAME_FULL=`hostname -f`
PRIMARY_IP=`hostname -I`

clear


#############################################################################
# Begin user interaction

echo "================="
echo "SharedServerTools"
echo "================="
echo
echo "This script is designed to turn a clean ubuntu installation into a working, secured shared web server."
echo "Ideally this script should be run as the very first thing you do with your new VPS. It will alter config files with no regard for their current state."
echo 
echo "The process is quite simple, but you will need to answer some questions first:"
echo
echo


#############################################
# Check for updates

echo "================"
echo "Security Updates"
echo "================"
echo 
echo "Before we start, it is advisable to check for and install any pending updates."
read -p "Would you like to do this now? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	echo
	echo
	apt update
	apt upgrade -y

	echo
	echo
	echo "It is best to restart you server after significant updates."
	read -p "Would you like to do this now? [y/N]" -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		clear
		echo "After rebooting, run this script again to continue setup."
		echo
		reboot
	fi
fi

############################################
# Secure root account

clear

echo "================"
echo "Account Security"
echo "================"
echo 
echo "If your installation of ubuntu came with a default root password, it should be changed."
read -p "Would you like to do this now? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
        echo
        echo
	passwd root
	echo
	echo
fi

echo "It is bad practice to log into the root account to do work. It is better to create a personal account with sudo access."
read -p "Would you like to do this now? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
        echo
        echo
        read -p "Desired username:" new_username
	adduser $new_username
	echo
	usermod -aG sudo $new_username
        echo
        echo
fi


echo "It is also bad practice to allow root ssh access (as this is the most common point of attack)."
read -p "Would you disable root ssh login capabilities now? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	replace_config_param /etc/ssh/sshd_config PermitRootLogin no
	#Leave sshd restart untill next reboot
fi




#################################################
# Setup hostname

clear

echo "==============="
echo "Server Hostname"
echo "==============="

echo "It is important that the server (and this script) know the fully qualified domain name that refers to this server."
echo "Here are the current settings:"
echo
echo "Current primary IP: "$PRIMARY_IP" (This should be a single ip address, if more listed please correct)"
echo "Current full hostname: "$HOSTNAME_FULL
echo "Current short hostname: "$HOSTNAME_SHORT
echo 
echo "This script needs to know the domain that points to this server so it can obtain SSL certificates."
echo
read -p "Would you like to change these settings now? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then

	read -p "Please enter the primary IP (currently: ${PRIMARY_IP}):" TEMP_PIP
	read -p "Please enter the new full host name (currently: $HOSTNAME_FULL):" TEMP_HN_FULL
	read -p "Please enter the new short host name (currently: $HOSTNAME_SHORT):" TEMP_HN_SHORT
	echo
	echo "The settings you entered were:"
	echo "Primary IP: "$TEMP_PIP
	echo "Full hostname: "$TEMP_HN_FULL
	echo "Short hostname: "$TEMP_HN_SHORT
	echo
	read -p "Would you like to save these settings? [y/N]" -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		PRIMARY_IP=$TEMP_PIP

		#Sort out short hostname
		hostname $TEMP_HN_SHORT
		HOSTNAME_SHORT=$TEMP_HN_SHORT
		echo $TEMP_HN_SHORT > /etc/hostname

		#Save full hostname in host file
		HOSTNAME_FULL=$TEMP_HN_FULL
		apply_template /etc/hosts hosts
	else
		echo "Changes abandoned"
	fi
fi

