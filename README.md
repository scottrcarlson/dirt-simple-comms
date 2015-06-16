# dirt-simple-comms

The goal is integrate various useful tools for de-centrialized encrypted p2p communication.
----------------------------
1. End to End Encyption via SSH
2. UDP/TCP Conversion with Netcat
3. IHU (I Hear U) for Audio Chat
4. utalk for Text Chat
5. Option to use SLIP to run the stack over serial.
6. Transport Medium (Internet, Serial, RF)
7. Text Mode Only 
----------------------------
Tested on RPi and Debian Linux.
More to details to follow..

----------------------------
SSH Setup
Configure for Resiliance / Compression / Clean Exit on Forward Failure

1. Generate Keys
2. Share Public Keys with Opposing End Points
3. Create ~/.ssh/config (if it doesn't already exist)
4. Modify the config
TCPKeepAlive no
ServerAliveInterval 60
ServerAliveCountMax 5760
Compression yes
CompressionLevel 6
ExitOnForwardFailure yes
----------------------------
