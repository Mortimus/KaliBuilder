#!/bin/bash

# Update to your VPN local IP
ping -c4 -I tun0 8.8.8.8 > /dev/null

if [ $? != 0 ]
then
	echo "$(date): No Network Connection, Restarting OpenVPN Service..."
	/usr/bin/systemctl restart openvpn
fi
