#!/bin/bash
printf "Dirt Simple Comms v 0.1.5\n"
printf "........................\n"

function ctrl_c() {
    printf "\nExiting dsc.\nKeep it real! \n\n"
    printf "$IHU_PID $NC_IHU_PID $NC_UTALK_PID $SSH_PID $SLIP_PID\n\n"
    kill -1 $IHU_PID > /dev/null 1> /dev/null 2> /dev/null
    #kill -1 $NC_IHU_PID #2> /dev/null    #Seem to be getting som other PID
    #kill -1 $NC_UTALK_PID #2> /dev/null  #Seem to be getting some other PID
    killall nc --quiet > /dev/null 1> /dev/null 2> /dev/null
    kill -1 $SSH_PID1 2> /dev/null
    kill -1 $SSH_PID2 2> /dev/null
    kill -1 $SLIP_PID  2> /dev/null
    exit 0
}

function show_help() {
    printf "\nDirt Simple Comms v0.1\n"  
    printf "........................\n"
    printf "USAGE over ip\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --call\n"
    printf "AND on opposing machine\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --wait\n"
    printf "........................\n"
    printf "OR over serial via SLIP"
    printf "........................\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --slip /dev/ttyAMA0 --call\n"
    printf "AND on opposing machine\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --slip /dev/ttyUSB0 --wait\n"
    printf "........................\n"
    printf "OPTIONS\n"
    printf "    -l/, --local ip_addr       Local IP Address\n"
    printf "    -r/, --remote ip_addr      Remote IP Address\n"
    printf "    -s/, --slip serialDevice   Enable SLIP Mode over Serial Device, will use Local/Remote IP\n"
    printf "    -b/, --baud baudrate       Baud Rate (Default:115200)\n"
    printf "    --call                     Active Call Mode (i.e. client mode)\n"
    printf "    --wait                     Active Call Mode (i.e. client mode)\n" 
    printf "    --noinput                  Disable Audio Input for IHU\n"
    printf "........................\n\n"
}

#Initial Defaults
SLIP_BAUD=115200
ARG_VALID=0 # Simple argument validation mechanism (counter)

while [[ $# > 0 ]]
do
key="$1"

case $key in
    -l|--local)
    LOCAL_IP_ADDR="$2"
    shift # past argument=value
    ((ARG_VALID++))
    ;;
    -r|--remote)
    REMOTE_IP_ADDR="$2"
    shift
    ((ARG_VALID++))
    ;;
    -s|--slip)
    SLIP_DEV="$2"
    shift
    ;;
    -b|--baud)
    SLIP_BAUD="$2"
    shift
    ;;
    --call)
    CALL_MODE=YES
    ((ARG_VALID++))
    ;;
    --wait)
    CALL_MODE=NO
    ((ARG_VALID++))
    ;;
    --noinput)
    IHU_ARGS="$1"
    ;;
    --help)
    show_help
    exit 0
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

if [[ $ARG_VALID -ne 3 ]] ; then                  # Make final determination.
    printf "\n=== Invalid or missing arguments ===.\n\n"
    show_help
    exit 1
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

if [[ $SLIP_DEV != "" ]] ; then                  # Make final determination.
    #Create and Configure our SLIP
    printf "configuring SLIP Between $LOCAL_IP_ADDR --> $REMOTE_IP_ADDR Over $SLIP_DEV"
    slattach -p slip -s $SLIP_BAUD $SLIP_DEV > /dev/null &
    SLIP_PID=$!
    printf "PID ($SLIP_PID)..."
    sleep 1
    ifconfig sl0 $LOCAL_IP_ADDR pointopoint $REMOTE_IP_ADDR up > /dev/null
    sleep 1
    route add -host $REMOTE_IP_ADDR dev sl0 > /dev/null
    printf "done\n"

    #Lets try to find the remote machine to prop up their slip interface
    printf "waiting for remote machine..."
    ((count = 100))                            # Maximum number to try.
    while [[ $count -ne 0 ]] ; do
        ping -c 1 $REMOTE_IP_ADDR > /dev/null               # Try once.
        rc=$?
        if [[ $rc -eq 0 ]] ; then
            ((count = 1))                      # If okay, flag to exit loop.
        fi
        ((count = count - 1))                  # So we don't go forever.
    done

    if [[ $rc -eq 0 ]] ; then                  # Make final determination.
        printf "ok\n"

    else
        printf "failed\n"
        printf "could not find machine at $REMOTE_IP_ADDR\n"
        exit 1
    fi
fi

if [[ $CALL_MODE == "YES" ]] ; then                  # Make final determination.
    printf "ok\n"
    #Time to create our ssh tunnel (local port forward)
    printf "creating ssh tunnel..."
    ssh -N -L 1794:localhost:1794 scott@$REMOTE_IP_ADDR &
    SSH_PID1=$!
    ssh -N -L 1700:localhost:1700 scott@$REMOTE_IP_ADDR &
    SSH_PID2=$!
    printf "PID ($SSH_PID)..."
    printf "done.\n"
fi

#Now we must create a udp/tcp converter with netcat
if [[ $CALL_MODE == "YES" ]] ; then                  # Make final determination.
    printf "creating udp to tcp converter..."
    mkfifo /tmp/fifo_dsc-ihu 2> /dev/null
    nc -l -u -p 1793 < /tmp/fifo_dsc-ihu | nc localhost 1794 > /tmp/fifo_dsc-ihu &
    NC_IHU_PID=$!

    mkfifo /tmp/fifo_dsc-utalk 2> /dev/null
    nc -l -u -p 1701 < /tmp/fifo_dsc-utalk | nc localhost 1700 > /tmp/fifo_dsc-utalk &
    NC_UTALK_PID=$!
else
    printf "creating tcp to udp converter..."
    mkfifo /tmp/fifo_dsc-ihu 2> /dev/null
    nc -l -p 1794 < /tmp/fifo_dsc | nc -u localhost 1793 > /tmp/fifo_dsc &
    NC_IHU_PID=$!

    mkfifo /tmp/fifo_dsc-utalk 2> /dev/null
    nc -l -p 1700 < /tmp/fifo_dsc-utalk | nc -u localhost 1701 > /tmp/fifo_dsc-utalk &
    NC_UTALK_PID=$!
fi
printf "done.\n"

#HACK Waiting to make sure remote machine is waiting for a call (ihu)
printf "Pausing 10 seconds to allow remote machine to intialize."
if [[ $CALL_MODE == "YES" ]] ; then
    sleep 10
fi

#Start IHU
printf "Starting IHU.\n"
if [[ $CALL_MODE == "YES" ]] ; then
    ihu --call $REMOTE_IP_ADDR --nogui > /dev/null 2> /dev/null &
else
    printf "Waiting for a call\n"
    ihu --wait --nogui $IHU_ARGS > /dev/null 2> /dev/null &
fi
IHU_PID=$!

#Start utalk
printf "Starting utalk.\n"
if [[ $CALL_MODE == "YES" ]] ; then
    utalk -c $REMOTE_IP_ADDR 1701
else
    utalk -s 1701
fi

#Exit Clean
ctrl_c
