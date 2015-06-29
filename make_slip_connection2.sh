#!/bin/bash
stty -F /dev/ttyAMA0 raw speed 38400
slattach -dv -p slip /dev/ttyAMA0 &
SLATTACH_PID1=${!}
echo
sudo ifconfig sl0 192.168.0.2 pointopoint 192.168.0.1 up
sudo route add -host 192.168.0.1 dev sl0

echo "slattach pid: " ${SLATTACH_PID1}
