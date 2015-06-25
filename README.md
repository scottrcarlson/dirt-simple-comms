# [dirt simple comms]

The goal is integrate various useful tools for de-centrialized authenticated/encrypted communication.

What 
----------------------------
1. Transport Medium (Internet, Serial, RF)
2. End to End Encyption via SSH (Port Forwarding)
3. Support UDP based tools over SSH  ( PartyA<->[UDP--<>TCP<--->SSH_TUNNEL<--->TCP<>UDP]<->PartyB )
4. IHU (I Hear U) for VOIP Chat (UDP {Investigate broken TCP?])
5. utalk for Text Chat (UDP)
6. Option to use SLIP to run the stack over serial.
7. Text Mode Exclusive

----------------------------
More details to follow..
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


Panstamp NRG Hooked up to RPI UART
GPIO 17 Used for Radio Reset

gpio -g mode 17 out
gpio -g write 17 1
