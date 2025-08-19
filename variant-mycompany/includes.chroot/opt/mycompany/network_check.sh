#!/bin/bash

# Update to your VPN local IP
ping -c4 -I tun0 8.8.8.8 > /dev/null

if [ $? != 0 ]
then
	echo "$(date): No Network Connection, Rebooting Machine"
	sudo /usr/sbin/reboot now
fi
