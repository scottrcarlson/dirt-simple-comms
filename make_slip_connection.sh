#!/bin/bash

socat -ddd -ddd PTY,raw,echo=0 "EXEC:'python panstamp_bridge.py /dev/ttyUSB1',pty,raw,echo=0" &
SOCAT_PID1=${!}
echo
read -p 'Enter PTY number (eg "12"): ' PTY1
sudo slattach -dv -p slip /dev/pts/${PTY1} &
SLATTACH_PID1=${!}
echo
read -p 'Enter interface name (eg "sl0"): ' IFACE1
sudo ifconfig ${IFACE1} 192.168.0.1 pointopoint 192.168.0.2 up
sudo route add -host 192.168.0.2 dev ${IFACE1}
2.168.0.1 dev ${IFACE2}

echo "slattach pid: " ${SLATTACH_PID1} 
echo "socat pid: " ${SOCAT_PID1} 
